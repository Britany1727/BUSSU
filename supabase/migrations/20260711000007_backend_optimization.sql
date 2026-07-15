-- =============================================================================
-- Andes Mobility: Fase de Optimización Backend
--
-- Índices, políticas RLS corregidas, trigger optimizado, CHECKs
-- =============================================================================

-- =============================================================================
-- 1. ÍNDICES ESPACIALES POSTGIS (CRÍTICO)
-- =============================================================================

-- 1.1 Posición de buses en tiempo real (la tabla más consultada espacialmente)
create index if not exists idx_blp_location
  on bus_live_position using gist (location);

-- 1.2 Historial de telemetría (consultas espaciales históricas)
create index if not exists idx_telemetry_location
  on bus_telemetry_history using gist (location);

-- 1.3 Polyline de rutas (st_length, st_linelocatepoint, st_dwithin)
create index if not exists idx_routes_polyline
  on routes using gist (polyline);

-- =============================================================================
-- 2. ÍNDICES DE CLAVES FORÁNEAS (ALTO IMPACTO EN RLS)
-- =============================================================================

-- 2.1 Drivers por cooperativa (cada RLS check)
create index if not exists idx_drivers_cooperativa
  on drivers(cooperativa_id);

create index if not exists idx_drivers_assigned_bus
  on drivers(assigned_bus_id);

-- 2.2 Rutas por cooperativa (cada RLS check)
create index if not exists idx_routes_cooperativa
  on routes(cooperativa_id);

-- 2.3 Buses por cooperativa y ruta (RLS + queries frecuentes)
create index if not exists idx_buses_cooperativa
  on buses(cooperativa_id);

create index if not exists idx_buses_route
  on buses(route_id);

-- 2.4 Perfiles
create index if not exists idx_profiles_cooperativa
  on profiles(cooperativa_id);

-- =============================================================================
-- 3. ÍNDICES COMPUESTOS PARA QUERIES FRECUENTES
-- =============================================================================

-- 3.1 Eventos de parada: búsqueda por bus+stop+evento (geocerca trigger)
create index if not exists idx_bse_bus_stop_event
  on bus_stop_events(bus_id, stop_id, event_type, occurred_at desc)
  where event_type = 'arrival';

-- 3.2 Presencia de usuarios (push notification query)
create index if not exists idx_usp_stop_detected
  on user_stop_presence(stop_id, detected_at desc);

create index if not exists idx_usp_user
  on user_stop_presence(user_id);

-- 3.3 Viajes por bus + estado (geocerca trigger subquery)
create index if not exists idx_trips_bus_status
  on trips(bus_id, status)
  where status = 'active';

-- 3.4 Solicitudes de parada
create index if not exists idx_stop_requests_driver
  on stop_requests(driver_id);

-- 3.5 Chat
create index if not exists idx_chat_conv_driver
  on chat_conversations(driver_id);

create index if not exists idx_chat_conv_coop
  on chat_conversations(cooperativa_id);

create index if not exists idx_chat_msg_sender
  on chat_messages(sender_id);

-- 3.6 IoT
create index if not exists idx_device_registry_bus
  on device_registry(bus_id);

create index if not exists idx_bridge_health_heartbeat
  on bridge_health(last_heartbeat desc);

-- 3.7 Cola offline con orden
drop index if exists idx_offline_queue_pending;
create index if not exists idx_offline_queue_pending_order
  on telemetry_offline_queue(processed, retries, enqueued_at)
  where processed = false and retries < 5;

-- =============================================================================
-- 4. CONSTRAINTS DE INTEGRIDAD
-- =============================================================================

-- 4.1 Capacidad de bus positiva
alter table buses drop constraint if exists chk_capacity_positive;
alter table buses add constraint chk_capacity_positive
  check (capacity > 0) not valid;
alter table buses validate constraint chk_capacity_positive;

-- 4.2 Pasajeros no negativos
alter table bus_live_position drop constraint if exists chk_passengers_non_negative;
alter table bus_live_position add constraint chk_passengers_non_negative
  check (passenger_count >= 0) not valid;
alter table bus_live_position validate constraint chk_passengers_non_negative;

-- 4.3 Viaje: end >= start
alter table trips drop constraint if exists chk_trip_end_after_start;
alter table trips add constraint chk_trip_end_after_start
  check (ended_at is null or ended_at >= started_at) not valid;
alter table trips validate constraint chk_trip_end_after_start;

-- 4.4 Velocidad en rango razonable
alter table bus_live_position drop constraint if exists chk_speed_range;
alter table bus_live_position add constraint chk_speed_range
  check (speed_kmh is null or (speed_kmh >= 0 and speed_kmh <= 200))
  not valid;
alter table bus_live_position validate constraint chk_speed_range;

-- =============================================================================
-- 5. CORRECCIÓN DE POLÍTICAS RLS (CRÍTICO)
-- =============================================================================

-- 5.1 bus_live_position: restringir INSERT/UPDATE a service_role
-- (antes usaba using(true) — cualquier usuario autenticado podía modificar)
drop policy if exists "Servicio puente inserta posición (service_role)" on bus_live_position;
drop policy if exists "Servicio puente actualiza posición (service_role)" on bus_live_position;

create policy "Bridge manages live position (insert)"
  on bus_live_position for insert
  with check (auth.role() = 'service_role');

create policy "Bridge manages live position (update)"
  on bus_live_position for update
  using (auth.role() = 'service_role');

-- 5.2 trips: cooperativa_admin solo gestiona viajes de su flota
drop policy if exists "Admin coop gestiona viajes de su flota" on trips;
create policy "Admin coop gestiona viajes de su flota"
  on trips for update
  using (
    exists (
      select 1 from buses b
      where b.id = trips.bus_id
        and b.cooperativa_id = auth_user_cooperativa()
    )
    or auth_user_role() = 'municipal_admin'
  );

-- 5.3 trips: conductor solo inicia viaje en bus de su cooperativa
drop policy if exists "Conductor inicia viaje" on trips;
create policy "Conductor inicia viaje en su cooperativa"
  on trips for insert
  with check (
    driver_id = auth.uid()
    and exists (
      select 1 from buses b
      join drivers d on d.cooperativa_id = b.cooperativa_id
      where b.id = bus_id and d.id = auth.uid()
    )
  );

-- 5.4 chat_messages: verificar pertenencia a conversación al insertar
drop policy if exists "Participantes envían mensajes" on chat_messages;
create policy "Participantes envían mensajes"
  on chat_messages for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from chat_conversations c
      where c.id = chat_messages.conversation_id
        and (
          c.driver_id = auth.uid()
          or c.cooperativa_id = auth_user_cooperativa()
          or auth_user_role() = 'municipal_admin'
        )
    )
  );

-- 5.5 Storage: restaurar validación de carpeta de usuario
drop policy if exists "Usuario sube su avatar" on storage.objects;
create policy "Usuario sube su avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- =============================================================================
-- 6. OPTIMIZACIÓN DE TRIGGER GEOCERCA
-- =============================================================================

create or replace function check_stop_geofence()
returns trigger as $$
declare
  nearest record;
  previous_stop_id uuid;
  active_trip_id uuid;
begin
  -- Salida temprana: bus sin ruta
  if not exists (
    select 1 from buses where id = new.bus_id and route_id is not null
  ) then
    return new;
  end if;

  -- Caché: obtener active_trip_id una sola vez
  active_trip_id := (
    select id from trips
    where bus_id = new.bus_id and status = 'active'
    order by started_at desc limit 1
  );

  -- Buscar parada más cercana
  select s.id
  into nearest
  from stops s
  where s.route_id = (select route_id from buses where id = new.bus_id)
    and st_dwithin(s.location, new.location, 30)
  order by st_distance(s.location, new.location)
  limit 1;

  -- Detectar departure: última parada donde estaba sin departure
  select bse.stop_id
  into previous_stop_id
  from bus_stop_events bse
  where bse.bus_id = new.bus_id
    and bse.event_type = 'arrival'
    and bse.occurred_at > now() - interval '30 minutes'
    and not exists (
      select 1 from bus_stop_events bse2
      where bse2.bus_id = bse.bus_id
        and bse2.stop_id = bse.stop_id
        and bse2.event_type = 'departure'
        and bse2.occurred_at > bse.occurred_at
    )
  order by bse.occurred_at desc
  limit 1;

  -- Si salió del radio de la parada anterior
  if previous_stop_id is not null and nearest.id is null then
    insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
    values (new.bus_id, previous_stop_id, active_trip_id, 'departure')
    on conflict do nothing;
    return new;
  end if;

  -- Si entró a una nueva parada
  if nearest.id is not null then
    if previous_stop_id is not null and nearest.id != previous_stop_id then
      insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
      values (new.bus_id, previous_stop_id, active_trip_id, 'departure')
      on conflict do nothing;
    end if;

    insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
    select new.bus_id, nearest.id, active_trip_id, 'arrival'
    where not exists (
      select 1 from bus_stop_events
      where bus_id = new.bus_id
        and stop_id = nearest.id
        and event_type = 'arrival'
        and occurred_at > now() - interval '5 minutes'
    );
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_check_stop_geofence on bus_live_position;
create trigger trg_check_stop_geofence
  after insert or update on bus_live_position
  for each row
  when (old is null or old.location is distinct from new.location)
  execute function check_stop_geofence();

-- =============================================================================
-- 7. VISTA MATERIALIZADA — Fleet Health
-- =============================================================================

drop materialized view if exists fleet_health_mv;
create materialized view fleet_health_mv as
select
  c.id as cooperativa_id,
  c.name as cooperativa_name,
  count(distinct b.id) as total_buses,
  count(distinct blp.bus_id) filter (
    where blp.updated_at > now() - interval '30 seconds'
  ) as active_buses,
  coalesce(round(avg(blp.occupancy_pct) filter (
    where blp.updated_at > now() - interval '30 seconds'
  )), 0) as avg_occupancy,
  coalesce(sum(blp.passenger_count) filter (
    where blp.updated_at > now() - interval '30 seconds'
  ), 0) as total_passengers,
  count(distinct d.id) as total_drivers
from cooperativas c
left join buses b on b.cooperativa_id = c.id
left join bus_live_position blp on blp.bus_id = b.id
left join drivers d on d.cooperativa_id = c.id
where c.status = 'active'
group by c.id, c.name;

create unique index if not exists idx_fleet_health_mv_coop
  on fleet_health_mv(cooperativa_id);

-- =============================================================================
-- 8. FUNCIÓN RPC OPTIMIZADA — Reporte Municipal
-- =============================================================================

create or replace function get_municipal_report()
returns json language sql stable as $$
  select json_build_object(
    'total_cooperativas', (select count(*) from cooperativas where status = 'active'),
    'total_buses', (select count(*) from buses),
    'active_buses', (select count(*) from bus_live_position
      where updated_at > now() - interval '30 seconds'),
    'total_passengers', (select coalesce(sum(passenger_count), 0) from bus_live_position),
    'unresolved_alerts', (select count(*) from system_alerts where resolved_at is null),
    'fleet_health_pct', (
      select case when count(*) = 0 then 0
        else round(
          count(*) filter (
            where blp.updated_at > now() - interval '30 seconds'
          )::numeric / count(*)::numeric * 100
        ) end
      from buses b
      left join bus_live_position blp on blp.bus_id = b.id
    ),
    'generated_at', now()
  );
$$;

-- =============================================================================
-- 9. RPC IOT — Agregar LIMIT
-- =============================================================================

create or replace function get_cooperativa_iot_status(coop_id uuid)
returns table (
  bus_plate text,
  device_id text,
  device_status text,
  last_seen timestamptz,
  firmware_version text,
  seconds_since_last_telemetry bigint
) language sql stable as $$
  select
    b.plate,
    dr.device_id,
    dr.status as device_status,
    dr.last_seen,
    dr.firmware_version,
    extract(epoch from (now() - dr.last_seen))::bigint as seconds_since_last_telemetry
  from device_registry dr
  join buses b on b.id = dr.bus_id
  where b.cooperativa_id = coop_id
  order by dr.last_seen desc
  limit 200;
$$;

-- =============================================================================
-- 10. RPC — Agregar límite de tiempo a get_route_performance
-- =============================================================================

create or replace function get_route_performance(
  coop_id uuid,
  lookback_days int default 30
)
returns table (
  route_id uuid,
  route_name text,
  total_trips bigint,
  completed_trips bigint,
  avg_occupancy double precision,
  avg_speed double precision,
  total_passengers bigint
) language sql stable as $$
  select
    r.id as route_id,
    r.name as route_name,
    count(t.id) as total_trips,
    count(t.id) filter (where t.status = 'completed') as completed_trips,
    coalesce(avg(case when b.capacity > 0 then (th.passenger_count::double precision / b.capacity) * 100 end), 0) as avg_occupancy,
    coalesce(avg(th.speed_kmh), 0) as avg_speed,
    coalesce(sum(th.passenger_count), 0) as total_passengers
  from routes r
  left join trips t on t.route_id = r.id
    and t.started_at > now() - make_interval(days => lookback_days)
  left join buses b on b.id = t.bus_id
  left join bus_telemetry_history th on th.bus_id = t.bus_id
    and th.recorded_at between t.started_at and coalesce(t.ended_at, now())
    and th.recorded_at > now() - make_interval(days => lookback_days)
  where r.cooperativa_id = coop_id
  group by r.id, r.name
  order by total_trips desc;
$$;
