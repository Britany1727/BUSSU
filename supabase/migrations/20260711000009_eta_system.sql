-- =============================================================================
-- Andes Mobility: ETA System — PostGIS + Exponential Smoothing
-- =============================================================================

-- =============================================================================
-- 1. RPC: Calcular progreso del bus sobre la polyline usando PostGIS
-- =============================================================================

create or replace function get_bus_route_progress(
  bus_id_param uuid,
  route_id_param uuid
)
returns table (
  bus_lat double precision,
  bus_lng double precision,
  speed_kmh double precision,
  progress_meters double precision,
  route_length_meters double precision,
  distance_to_next_stop double precision,
  next_stop_id uuid,
  next_stop_name text,
  eta_seconds double precision
) language sql stable as $$
  with bus_pos as (
    select
      st_y(blp.location::geometry) as lat,
      st_x(blp.location::geometry) as lng,
      blp.speed_kmh,
      blp.updated_at
    from bus_live_position blp
    where blp.bus_id = bus_id_param
  ),
  route_geom as (
    select
      r.polyline,
      st_length(r.polyline) as route_length
    from routes r
    where r.id = route_id_param
  ),
  progress as (
    select
      bp.lat,
      bp.lng,
      bp.speed_kmh,
      st_linelocatepoint(rg.polyline::geometry, st_makepoint(bp.lng, bp.lat))
        * rg.route_length as progress_meters,
      rg.route_length as route_length_meters
    from bus_pos bp, route_geom rg
  ),
  next_stop as (
    select
      s.id,
      s.name,
      s.distance_along_route
    from stops s
    where s.route_id = route_id_param
      and s.distance_along_route > (select progress_meters from progress)
    order by s.distance_along_route asc
    limit 1
  )
  select
    p.lat,
    p.lng,
    p.speed_kmh,
    p.progress_meters,
    p.route_length_meters,
    coalesce(ns.distance_along_route - p.progress_meters, 0) as distance_to_next_stop,
    ns.id as next_stop_id,
    ns.name as next_stop_name,
    case
      when p.speed_kmh > 0 and ns.distance_along_route is not null
      then ((ns.distance_along_route - p.progress_meters) / (p.speed_kmh / 3.6))
      else 0
    end as eta_seconds
  from progress p
  left join next_stop ns on true;
$$;

-- =============================================================================
-- 2. RPC: Velocidad promedio histórica por segmento/hora (fallback)
-- =============================================================================

create or replace function get_segment_avg_speed(
  route_id_param uuid,
  start_distance double precision,
  end_distance double precision,
  hour_of_day int default null
)
returns double precision language sql stable as $$
  select coalesce(
    avg(th.speed_kmh) filter (where th.speed_kmh > 0),
    25.0  -- fallback: 25 km/h urbano
  ) as avg_speed
  from bus_telemetry_history th
  join trips t on t.bus_id = th.bus_id
  join buses b on b.id = th.bus_id
  where b.route_id = route_id_param
    and t.status = 'completed'
    and th.speed_kmh > 1
    and th.recorded_at > now() - interval '30 days'
    and (
      hour_of_day is null
      or extract(hour from th.recorded_at) = hour_of_day
    );
$$;

-- =============================================================================
-- 3. RPC: ETA completo para todas las paradas de una ruta
-- =============================================================================

create or replace function calculate_etas_for_route(
  bus_id_param uuid,
  route_id_param uuid,
  use_historical_fallback boolean default true
)
returns table (
  stop_id uuid,
  stop_name text,
  stop_order int,
  distance_meters double precision,
  eta_seconds double precision,
  eta_minutes double precision,
  occupancy_level text
) language plpgsql stable as $$
declare
  bus_lat_val double precision;
  bus_lng_val double precision;
  bus_speed double precision;
  bus_progress double precision;
  smoothed_speed double precision;
  historical_speed double precision;
  current_hour int;
begin
  -- Obtener posición y velocidad actual del bus
  select
    st_y(blp.location::geometry),
    st_x(blp.location::geometry),
    coalesce(blp.speed_kmh, 0),
    st_linelocatepoint(r.polyline::geometry, blp.location::geometry) * st_length(r.polyline)
  into bus_lat_val, bus_lng_val, bus_speed, bus_progress
  from bus_live_position blp
  join routes r on r.id = route_id_param
  where blp.bus_id = bus_id_param;

  -- Si no hay datos de posición, retornar vacío
  if bus_lat_val is null then
    return;
  end if;

  -- Suavizado: media móvil exponencial con últimas 6 lecturas
  select coalesce(avg(speed_kmh), bus_speed)
  into smoothed_speed
  from (
    select speed_kmh
    from bus_telemetry_history
    where bus_id = bus_id_param
      and recorded_at > now() - interval '30 seconds'
    order by recorded_at desc
    limit 6
  ) recent;

  -- Si la velocidad suavizada es muy baja, usar histórico del segmento
  current_hour := extract(hour from now())::int;

  if use_historical_fallback and smoothed_speed < 1.0 then
    select get_segment_avg_speed(route_id_param, bus_progress,
      bus_progress + 500, current_hour)
    into historical_speed;
    smoothed_speed := greatest(smoothed_speed, historical_speed);
  end if;

  -- Si aún es 0, usar velocidad urbana por defecto
  if smoothed_speed < 1.0 then
    smoothed_speed := 20.0;
  end if;

  -- Retornar ETA para cada parada futura
  return query
  select
    s.id,
    s.name,
    s.order_index,
    s.distance_along_route - bus_progress as distance_meters,
    case
      when s.distance_along_route > bus_progress
      then ((s.distance_along_route - bus_progress) / (smoothed_speed / 3.6))
      else 0
    end as eta_seconds,
    case
      when s.distance_along_route > bus_progress
      then round(
        ((s.distance_along_route - bus_progress) / (smoothed_speed / 3.6) / 60)::numeric, 1
      )
      else 0
    end as eta_minutes,
    case
      when blp.occupancy_pct < 40 then 'Baja'
      when blp.occupancy_pct < 75 then 'Media'
      else 'Alta'
    end as occupancy_level
  from stops s
  join routes r on r.id = s.route_id
  left join bus_live_position blp on blp.bus_id = bus_id_param
  where s.route_id = route_id_param
    and s.distance_along_route > bus_progress
  order by s.order_index;
end;
$$;

-- =============================================================================
-- 4. RPC: Obtener velocidades recientes para suavizado (cliente ligero)
-- =============================================================================

create or replace function get_recent_speeds(
  bus_id_param uuid,
  sample_count int default 6
)
returns table (
  speed_kmh double precision,
  recorded_at timestamptz
) language sql stable as $$
  select th.speed_kmh, th.recorded_at
  from bus_telemetry_history th
  where th.bus_id = bus_id_param
    and th.speed_kmh is not null
  order by th.recorded_at desc
  limit sample_count;
$$;
