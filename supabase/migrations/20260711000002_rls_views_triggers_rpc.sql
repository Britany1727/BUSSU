-- =============================================================================
-- Andes Mobility: RLS, Views, Triggers, RPC, PostGIS
-- =============================================================================

-- Asegurar tipo enum (creado en initial_schema)
do $$ begin
  create type user_role as enum (
    'usuario',
    'conductor',
    'cooperativa_admin',
    'municipal_admin'
  );
exception when duplicate_object then null;
end $$;

-- 4. ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- 4.1 Habilitar RLS en todas las tablas
alter table profiles enable row level security;
alter table cooperativas enable row level security;
alter table drivers enable row level security;
alter table routes enable row level security;
alter table buses enable row level security;
alter table stops enable row level security;
alter table bus_live_position enable row level security;
alter table bus_telemetry_history enable row level security;
alter table trips enable row level security;
alter table bus_stop_events enable row level security;
alter table stop_requests enable row level security;
alter table system_alerts enable row level security;
alter table premium_subscriptions enable row level security;
alter table chat_conversations enable row level security;
alter table chat_messages enable row level security;
alter table device_tokens enable row level security;
alter table user_stop_presence enable row level security;

-- 4.2 Helper: obtener rol del usuario actual
create or replace function auth_user_role()
returns user_role as $$
  select coalesce(
    (select role from profiles where id = auth.uid()),
    'usuario'::user_role
  );
$$ language sql stable security definer;

-- 4.3 Helper: obtener cooperativa_id del usuario
create or replace function auth_user_cooperativa()
returns uuid as $$
  select cooperativa_id from profiles where id = auth.uid();
$$ language sql stable security definer;

-- 4.4 Policies: profiles
drop policy if exists "Usuarios ven su propio perfil" on profiles;
create policy "Usuarios ven su propio perfil"
  on profiles for select
  using (id = auth.uid() or auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Usuarios actualizan su propio perfil" on profiles;
create policy "Usuarios actualizan su propio perfil"
  on profiles for update
  using (id = auth.uid());

drop policy if exists "Admin municipal gestiona todos los perfiles" on profiles;
create policy "Admin municipal gestiona todos los perfiles"
  on profiles for all
  using (auth_user_role() = 'municipal_admin');

-- 4.5 Policies: cooperativas
drop policy if exists "Lectura pública de cooperativas" on cooperativas;
create policy "Lectura pública de cooperativas"
  on cooperativas for select
  using (true);

drop policy if exists "Admin municipal gestiona cooperativas" on cooperativas;
create policy "Admin municipal gestiona cooperativas"
  on cooperativas for all
  using (auth_user_role() = 'municipal_admin');

-- 4.6 Policies: drivers
drop policy if exists "Admin cooperativa ve sus conductores" on drivers;
create policy "Admin cooperativa ve sus conductores"
  on drivers for select
  using (
    cooperativa_id = auth_user_cooperativa()
    or auth_user_role() = 'municipal_admin'
  );

drop policy if exists "Admin cooperativa gestiona sus conductores" on drivers;
create policy "Admin cooperativa gestiona sus conductores"
  on drivers for all
  using (cooperativa_id = auth_user_cooperativa());

-- 4.7 Policies: routes
drop policy if exists "Rutas visibles para autenticados" on routes;
create policy "Rutas visibles para autenticados"
  on routes for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admin cooperativa gestiona sus rutas" on routes;
create policy "Admin cooperativa gestiona sus rutas"
  on routes for all
  using (cooperativa_id = auth_user_cooperativa());

-- 4.8 Policies: buses
drop policy if exists "Buses visibles para autenticados" on buses;
create policy "Buses visibles para autenticados"
  on buses for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admin cooperativa gestiona sus buses" on buses;
create policy "Admin cooperativa gestiona sus buses"
  on buses for all
  using (cooperativa_id = auth_user_cooperativa());

-- 4.9 Policies: bus_live_position (Realtime)
drop policy if exists "Posición de buses visible para autenticados" on bus_live_position;
create policy "Posición de buses visible para autenticados"
  on bus_live_position for select
  using (auth.role() = 'authenticated');

drop policy if exists "Servicio puente inserta posición (service_role)" on bus_live_position;
create policy "Servicio puente inserta posición (service_role)"
  on bus_live_position for insert
  with check (true);

drop policy if exists "Servicio puente actualiza posición (service_role)" on bus_live_position;
create policy "Servicio puente actualiza posición (service_role)"
  on bus_live_position for update
  using (true);

-- 4.10 Policies: stops
drop policy if exists "Paradas visibles para autenticados" on stops;
create policy "Paradas visibles para autenticados"
  on stops for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admin cooperativa gestiona paradas de sus rutas" on stops;
create policy "Admin cooperativa gestiona paradas de sus rutas"
  on stops for all
  using (
    exists (
      select 1 from routes r
      where r.id = stops.route_id
      and r.cooperativa_id = auth_user_cooperativa()
    )
  );

-- 4.11 Policies: system_alerts
drop policy if exists "Alertas visibles para autenticados" on system_alerts;
create policy "Alertas visibles para autenticados"
  on system_alerts for select
  using (auth.role() = 'authenticated');

drop policy if exists "Admin municipal gestiona alertas" on system_alerts;
create policy "Admin municipal gestiona alertas"
  on system_alerts for all
  using (auth_user_role() = 'municipal_admin');

-- 4.12 Policies: chat
drop policy if exists "Chat visible para participantes" on chat_messages;
create policy "Chat visible para participantes"
  on chat_messages for select
  using (
    exists (
      select 1 from chat_conversations c
      where c.id = chat_messages.conversation_id
      and (c.driver_id = auth.uid() or exists (
        select 1 from drivers d
        where d.id = c.driver_id
        and d.cooperativa_id = auth_user_cooperativa()
      ))
    )
  );

drop policy if exists "Participantes envían mensajes" on chat_messages;
create policy "Participantes envían mensajes"
  on chat_messages for insert
  with check (sender_id = auth.uid());

-- 4.13 Policies: premium
drop policy if exists "Usuario ve su suscripción" on premium_subscriptions;
create policy "Usuario ve su suscripción"
  on premium_subscriptions for select
  using (user_id = auth.uid() or auth_user_role() = 'municipal_admin');

-- 4.14 Policies: trips
drop policy if exists "Viajes visibles para participantes y admins" on trips;
create policy "Viajes visibles para participantes y admins"
  on trips for select
  using (
    driver_id = auth.uid()
    or auth_user_role() in ('cooperativa_admin', 'municipal_admin')
  );

-- 4.15 Policies: device_tokens
drop policy if exists "Usuario gestiona su token" on device_tokens;
create policy "Usuario gestiona su token"
  on device_tokens for all
  using (user_id = auth.uid());

-- 4.16 Policies: user_stop_presence
drop policy if exists "Usuario registra su presencia" on user_stop_presence;
create policy "Usuario registra su presencia"
  on user_stop_presence for insert
  with check (user_id = auth.uid());

drop policy if exists "Admins ven presencia de usuarios" on user_stop_presence;
create policy "Admins ven presencia de usuarios"
  on user_stop_presence for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

-- =============================================================================
-- 5. VIEWS
-- =============================================================================

-- 5.1 Vista pública de ocupación (3 niveles para usuarios free)
create or replace view bus_live_position_public as
select
  bus_id,
  speed_kmh,
  heading,
  updated_at,
  case
    when occupancy_pct < 40 then 'Baja'
    when occupancy_pct < 75 then 'Media'
    else 'Alta'
  end as occupancy_level
from bus_live_position;

-- 5.2 Vista consolidada de salud de flota por cooperativa
create or replace view fleet_health_view as
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

-- =============================================================================
-- 6. RPC FUNCTIONS
-- =============================================================================

-- 6.1 Rendimiento de rutas por cooperativa
create or replace function get_route_performance(coop_id uuid)
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
  left join buses b on b.id = t.bus_id
  left join bus_telemetry_history th on th.bus_id = t.bus_id
    and th.recorded_at between t.started_at and coalesce(t.ended_at, now())
  where r.cooperativa_id = coop_id
  group by r.id, r.name
  order by total_trips desc;
$$;

-- 6.2 Reporte público municipal
create or replace function get_municipal_report()
returns json language plpgsql stable as $$
declare
  result json;
begin
  select json_build_object(
    'total_cooperativas', (select count(*) from cooperativas where status = 'active'),
    'total_buses', (select count(*) from buses),
    'active_buses', (select count(*) from bus_live_position
      where updated_at > now() - interval '30 seconds'),
    'total_passengers', (select coalesce(sum(passenger_count), 0) from bus_live_position),
    'unresolved_alerts', (select count(*) from system_alerts where resolved_at is null),
    'fleet_health_pct', (
      select case
        when count(*) = 0 then 0
        else round(
          count(*) filter (where blp.updated_at > now() - interval '30 seconds')::numeric
          / count(*)::numeric * 100
        )
      end
      from buses b
      left join bus_live_position blp on blp.bus_id = b.id
    ),
    'generated_at', now()
  ) into result;

  return result;
end;
$$;

-- 6.3 Buses activos en una ruta (con posición y ocupación)
create or replace function get_active_buses_on_route(route_id_param uuid)
returns table (
  bus_id uuid,
  plate text,
  lat double precision,
  lng double precision,
  speed_kmh double precision,
  heading double precision,
  passenger_count int,
  occupancy_pct double precision,
  updated_at timestamptz
) language sql stable as $$
  select
    b.id as bus_id,
    b.plate,
    st_y(blp.location::geometry) as lat,
    st_x(blp.location::geometry) as lng,
    blp.speed_kmh,
    blp.heading,
    blp.passenger_count,
    blp.occupancy_pct,
    blp.updated_at
  from buses b
  inner join bus_live_position blp on blp.bus_id = b.id
  where b.route_id = route_id_param
    and blp.updated_at > now() - interval '60 seconds'
  order by blp.updated_at desc;
$$;

-- 6.4 Historial de viajes de un conductor
create or replace function get_driver_trip_history(driver_id_param uuid, limit_param int default 50)
returns table (
  trip_id uuid,
  bus_plate text,
  route_name text,
  started_at timestamptz,
  ended_at timestamptz,
  status text,
  avg_passengers double precision
) language sql stable as $$
  select
    t.id as trip_id,
    b.plate as bus_plate,
    r.name as route_name,
    t.started_at,
    t.ended_at,
    t.status,
    coalesce(avg(th.passenger_count), 0) as avg_passengers
  from trips t
  left join buses b on b.id = t.bus_id
  left join routes r on r.id = t.route_id
  left join bus_telemetry_history th on th.bus_id = t.bus_id
    and th.recorded_at between t.started_at and coalesce(t.ended_at, now())
  where t.driver_id = driver_id_param
  group by t.id, b.plate, r.name, t.started_at, t.ended_at, t.status
  order by t.started_at desc
  limit limit_param;
$$;

-- =============================================================================
-- 7. TRIGGERS
-- =============================================================================

-- 7.1 Geocerca de llegada a parada
create or replace function check_stop_geofence()
returns trigger as $$
declare
  nearest record;
begin
  select s.id, s.route_id
  into nearest
  from stops s
  where s.route_id = (
    select route_id from buses where id = new.bus_id
  )
  and st_dwithin(s.location, new.location, 30)
  order by st_distance(s.location, new.location)
  limit 1;

  if nearest.id is not null then
    insert into bus_stop_events (bus_id, stop_id, event_type)
    select new.bus_id, nearest.id, 'arrival'
    where not exists (
      select 1 from bus_stop_events
      where bus_id = new.bus_id
        and stop_id = nearest.id
        and occurred_at > now() - interval '5 minutes'
    );
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_check_stop_geofence on bus_live_position;
create trigger trg_check_stop_geofence
  after insert or update on bus_live_position
  for each row execute function check_stop_geofence();

-- 7.2 Actualizar updated_at automáticamente
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated_at on profiles;
create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at_column();

drop trigger if exists trg_routes_updated_at on routes;
create trigger trg_routes_updated_at
  before update on routes
  for each row execute function update_updated_at_column();

-- 7.3 Crear perfil automáticamente al registrarse
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, role, full_name, email)
  values (
    new.id,
    coalesce(
      (new.raw_user_meta_data->>'role')::user_role,
    'usuario'::user_role
    ),
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'fullName',
      new.email
    ),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =============================================================================
-- 8. REALTIME
-- =============================================================================

-- Habilitar Realtime para tablas de streaming
do $$ begin alter publication supabase_realtime add table bus_live_position; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table bus_stop_events; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table system_alerts; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table chat_messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table trips; exception when duplicate_object then null; end $$;
