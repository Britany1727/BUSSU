-- =============================================================================
-- BUSSU: Backend Fixes — índices, RPCs, materialized view refresh, seed data
-- =============================================================================

-- =============================================================================
-- Fix 1: Índice en stops.route_id (geocerca trigger escaneaba secuencialmente)
-- =============================================================================
create index if not exists idx_stops_route on stops(route_id);

-- =============================================================================
-- Fix 2: Índice compuesto para ordenamiento ETA (st_distance_along_route)
-- =============================================================================
create index if not exists idx_stops_route_distance
  on stops(route_id, distance_along_route);

-- =============================================================================
-- Fix 3: get_bus_route_progress — validar polyline IS NOT NULL en CTE
-- Fix 4: get_segment_avg_speed — usar start_distance/end_distance en WHERE
-- =============================================================================

create or replace function get_bus_route_progress(
  bus_id_param uuid,
  route_id_param uuid
)
returns table (
  bus_lat double precision, bus_lng double precision, speed_kmh double precision,
  progress_meters double precision, route_length_meters double precision,
  distance_to_next_stop double precision, next_stop_id uuid, next_stop_name text, eta_seconds double precision
) language sql stable as $$
  with bus_pos as (
    select st_y(blp.location::geometry) as lat, st_x(blp.location::geometry) as lng, blp.speed_kmh
    from bus_live_position blp where blp.bus_id = bus_id_param
  ),
  route_geom as (
    -- Fix 3: validar polyline IS NOT NULL
    select r.polyline, st_length(r.polyline) as route_length
    from routes r where r.id = route_id_param and r.polyline is not null
  ),
  progress as (
    select bp.lat, bp.lng, bp.speed_kmh,
      st_linelocatepoint(rg.polyline::geometry, st_makepoint(bp.lng, bp.lat)) * rg.route_length as progress_meters,
      rg.route_length as route_length_meters
    from bus_pos bp, route_geom rg
  ),
  next_stop as (
    select s.id, s.name, s.distance_along_route
    from stops s
    where s.route_id = route_id_param and s.distance_along_route > (select progress_meters from progress)
    order by s.distance_along_route asc limit 1
  )
  select p.lat, p.lng, p.speed_kmh, p.progress_meters, p.route_length_meters,
    coalesce(ns.distance_along_route - p.progress_meters, 0),
    ns.id, ns.name,
    case when p.speed_kmh > 0 and ns.distance_along_route is not null
      then ((ns.distance_along_route - p.progress_meters) / (p.speed_kmh / 3.6)) else 0 end
  from progress p left join next_stop ns on true;
$$;

create or replace function get_segment_avg_speed(
  route_id_param uuid,
  start_distance double precision,
  end_distance double precision,
  hour_of_day int default null
)
returns double precision language sql stable as $$
  -- Fix 4: usar start_distance y end_distance en el WHERE
  select coalesce(
    avg(th.speed_kmh) filter (where th.speed_kmh > 0),
    25.0
  ) as avg_speed
  from bus_telemetry_history th
  join trips t on t.bus_id = th.bus_id
  join buses b on b.id = th.bus_id
  join routes r on r.id = b.route_id
  join stops s on s.route_id = r.id
  where b.route_id = route_id_param
    and t.status = 'completed'
    and th.speed_kmh > 1
    and th.recorded_at > now() - interval '30 days'
    and s.distance_along_route >= start_distance
    and s.distance_along_route <= end_distance
    and (
      hour_of_day is null
      or extract(hour from th.recorded_at) = hour_of_day
    );
$$;

-- =============================================================================
-- Fix 10: pg_cron job para refrescar fleet_health_mv cada 30 segundos
-- =============================================================================
-- Requiere: create extension if not exists pg_cron;
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('refresh-fleet-health');
    exception when others then null;
    end;
    perform cron.schedule(
      'refresh-fleet-health',
      '30 seconds',
      'refresh materialized view concurrently fleet_health_mv'
    );
  end if;
end
$$;
