-- =============================================================================
-- Andes Mobility: Fase 1 de Estabilización — Correcciones Críticas
-- =============================================================================
-- IMPORTANTE: Copiar y pegar TODO este archivo de una sola vez en SQL Editor
-- =============================================================================

-- Asegurar tipo enum
do $$ begin
  create type user_role as enum (
    'usuario','conductor','cooperativa_admin','municipal_admin'
  );
exception when duplicate_object then null;
end $$;

-- Asegurar tablas base que podrían faltar
do $$ begin
  create table if not exists cooperativas (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    ruc text unique,
    status text not null default 'active' check (status in ('active','suspended','inactive')),
    created_by uuid,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    role user_role not null default 'usuario',
    full_name text,
    email text,
    is_premium boolean not null default false,
    device_id text,
    cooperativa_id uuid references cooperativas(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists drivers (
    id uuid primary key references profiles(id) on delete cascade,
    cooperativa_id uuid references cooperativas(id) on delete set null,
    license_number text,
    assigned_bus_id uuid,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists routes (
    id uuid primary key default gen_random_uuid(),
    cooperativa_id uuid references cooperativas(id) on delete cascade,
    name text not null,
    polyline geography(linestring, 4326),
    color text not null default '#001B44',
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists buses (
    id uuid primary key default gen_random_uuid(),
    plate text unique not null,
    cooperativa_id uuid references cooperativas(id) on delete cascade,
    route_id uuid references routes(id) on delete set null,
    capacity int not null default 40,
    hardware_device_id text unique,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists stops (
    id uuid primary key default gen_random_uuid(),
    route_id uuid not null references routes(id) on delete cascade,
    name text not null,
    location geography(point, 4326) not null,
    order_index int not null,
    distance_along_route double precision,
    beacon_uuid text,
    beacon_major int,
    beacon_minor int,
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists bus_live_position (
    bus_id uuid primary key references buses(id) on delete cascade,
    location geography(point, 4326),
    speed_kmh double precision,
    heading double precision,
    passenger_count int not null default 0,
    occupancy_pct double precision default 0,
    updated_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists bus_telemetry_history (
    id bigint generated always as identity primary key,
    bus_id uuid references buses(id) on delete cascade,
    location geography(point, 4326),
    speed_kmh double precision,
    passenger_count int not null default 0,
    recorded_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists trips (
    id uuid primary key default gen_random_uuid(),
    bus_id uuid references buses(id) on delete set null,
    route_id uuid references routes(id) on delete set null,
    driver_id uuid references drivers(id) on delete set null,
    started_at timestamptz,
    ended_at timestamptz,
    status text not null default 'scheduled' check (status in ('scheduled','active','completed','cancelled')),
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists bus_stop_events (
    id uuid primary key default gen_random_uuid(),
    bus_id uuid references buses(id) on delete cascade,
    stop_id uuid references stops(id) on delete cascade,
    trip_id uuid references trips(id) on delete cascade,
    event_type text not null check (event_type in ('arrival','departure')),
    occurred_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists stop_requests (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid references drivers(id) on delete cascade,
    proposed_lat double precision not null,
    proposed_lng double precision not null,
    justification text,
    status text not null default 'pending' check (status in ('pending','approved','rejected')),
    reviewed_by uuid references profiles(id),
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists chat_conversations (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid references drivers(id) on delete cascade,
    cooperativa_id uuid references cooperativas(id) on delete cascade,
    status text not null default 'open' check (status in ('open','closed')),
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists chat_messages (
    id bigint generated always as identity primary key,
    conversation_id uuid references chat_conversations(id) on delete cascade,
    sender_id uuid references profiles(id) on delete cascade,
    content text not null,
    sent_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists device_registry (
    id uuid primary key default gen_random_uuid(),
    device_id text unique not null,
    hardware_model text not null default 'ESP32-C3',
    bus_id uuid references buses(id) on delete set null,
    firmware_version text,
    last_heartbeat timestamptz default now(),
    status text not null default 'active' check (status in ('active','inactive','maintenance')),
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists bridge_health (
    device_id text primary key,
    cpu_pct double precision,
    ram_pct double precision,
    disk_pct double precision,
    wifi_rssi int,
    uptime_seconds bigint,
    recorded_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists bridge_logs (
    id bigint generated always as identity primary key,
    device_id text,
    level text default 'info',
    message text,
    recorded_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists system_alerts (
    id uuid primary key default gen_random_uuid(),
    scope text not null default 'system' check (scope in ('route','stop','system')),
    severity text not null default 'low' check (severity in ('low','medium','high')),
    title text not null,
    description text,
    route_id uuid references routes(id) on delete set null,
    created_by uuid references profiles(id) on delete set null,
    created_at timestamptz not null default now(),
    resolved_at timestamptz
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists premium_subscriptions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references profiles(id) on delete cascade,
    plan_id text not null default 'premium_mensual',
    status text not null default 'active' check (status in ('active','cancelled','expired')),
    started_at timestamptz not null default now(),
    expires_at timestamptz,
    payment_ref text,
    created_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists user_stop_presence (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references profiles(id) on delete cascade,
    stop_id uuid references stops(id) on delete cascade,
    detected_at timestamptz not null default now()
  );
exception when others then null;
end $$;

do $$ begin
  create table if not exists device_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references profiles(id) on delete cascade unique,
    token text not null,
    platform text not null default 'unknown',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );
exception when others then null;
end $$;

-- =============================================================================
-- Funciones SECURITY DEFINER
-- =============================================================================

create or replace function auth_user_role()
returns user_role
language sql stable security definer as $$
  select coalesce(
    (select role from profiles where id = auth.uid()),
    'usuario'::user_role
  );
$$;

create or replace function auth_user_cooperativa()
returns uuid
language sql stable security definer as $$
  select cooperativa_id from profiles where id = auth.uid();
$$;

create or replace function handle_new_user()
returns trigger
language plpgsql security definer as $$
declare
  raw_role text;
  valid_role user_role;
begin
  raw_role := new.raw_user_meta_data->>'role';
  valid_role := case raw_role
    when 'usuario' then 'usuario'::user_role
    when 'conductor' then 'conductor'::user_role
    when 'cooperativa_admin' then 'cooperativa_admin'::user_role
    when 'municipal_admin' then 'municipal_admin'::user_role
    else 'usuario'::user_role
  end;
  insert into profiles (id, role, full_name, email)
  values (
    new.id,
    valid_role,
    coalesce(
      trim(new.raw_user_meta_data->>'full_name'),
      trim(new.raw_user_meta_data->>'fullName'),
      trim(new.email)
    ),
    new.email
  );
  return new;
end;
$$;

-- =============================================================================
-- RLS: Habilitar en todas las tablas
-- =============================================================================

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

-- =============================================================================
-- RLS Policies: bus_telemetry_history
-- =============================================================================

drop policy if exists "Admins ven historial de telemetría" on bus_telemetry_history;
create policy "Admins ven historial de telemetría"
  on bus_telemetry_history for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Conductor ve historial de su bus asignado" on bus_telemetry_history;
create policy "Conductor ve historial de su bus asignado"
  on bus_telemetry_history for select
  using (
    exists (
      select 1 from drivers d
      join buses b on b.id = d.assigned_bus_id
      where d.id = auth.uid()
        and b.id = bus_telemetry_history.bus_id
    )
  );

-- =============================================================================
-- RLS Policies: bus_stop_events
-- =============================================================================

drop policy if exists "Admins ven eventos de parada" on bus_stop_events;
create policy "Admins ven eventos de parada"
  on bus_stop_events for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Conductor ve eventos de su viaje" on bus_stop_events;
create policy "Conductor ve eventos de su viaje"
  on bus_stop_events for select
  using (
    exists (
      select 1 from trips t
      where t.id = bus_stop_events.trip_id
        and t.driver_id = auth.uid()
    )
  );

-- =============================================================================
-- RLS Policies: stop_requests
-- =============================================================================

drop policy if exists "Conductor ve sus solicitudes de parada" on stop_requests;
create policy "Conductor ve sus solicitudes de parada"
  on stop_requests for select
  using (driver_id = auth.uid());

drop policy if exists "Admin cooperativa gestiona solicitudes de parada" on stop_requests;
create policy "Admin cooperativa gestiona solicitudes de parada"
  on stop_requests for all
  using (
    exists (
      select 1 from drivers d
      where d.id = stop_requests.driver_id
        and d.cooperativa_id = auth_user_cooperativa()
    )
    or auth_user_role() = 'municipal_admin'
  );

-- =============================================================================
-- RLS Policies: chat_conversations
-- =============================================================================

drop policy if exists "Participantes ven conversaciones" on chat_conversations;
create policy "Participantes ven conversaciones"
  on chat_conversations for select
  using (
    driver_id = auth.uid()
    or cooperativa_id = auth_user_cooperativa()
    or auth_user_role() = 'municipal_admin'
  );

drop policy if exists "Participantes gestionan conversaciones" on chat_conversations;
create policy "Participantes gestionan conversaciones"
  on chat_conversations for all
  using (
    driver_id = auth.uid()
    or cooperativa_id = auth_user_cooperativa()
  );

-- =============================================================================
-- RLS Policies: device_registry (seguras)
-- =============================================================================

drop policy if exists "Service role gestiona device registry" on device_registry;
drop policy if exists "Admins ven device registry" on device_registry;

create policy "Service role gestiona device registry"
  on device_registry for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "Admins ven device registry"
  on device_registry for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

-- =============================================================================
-- RLS Policies: premium_subscriptions
-- =============================================================================

drop policy if exists "Sistema crea suscripciones" on premium_subscriptions;
create policy "Sistema crea suscripciones"
  on premium_subscriptions for insert
  with check (auth.role() = 'service_role' or auth_user_role() = 'municipal_admin');

drop policy if exists "Municipal gestiona suscripciones" on premium_subscriptions;
create policy "Municipal gestiona suscripciones"
  on premium_subscriptions for update
  using (auth_user_role() = 'municipal_admin');

-- =============================================================================
-- RLS Policies: trips
-- =============================================================================

drop policy if exists "Conductor inicia viaje" on trips;
create policy "Conductor inicia viaje"
  on trips for insert
  with check (driver_id = auth.uid());

drop policy if exists "Conductor actualiza su viaje" on trips;
create policy "Conductor actualiza su viaje"
  on trips for update
  using (driver_id = auth.uid());

drop policy if exists "Admin coop gestiona viajes de su flota" on trips;
create policy "Admin coop gestiona viajes de su flota"
  on trips for update
  using (auth_user_role() = 'cooperativa_admin');

-- =============================================================================
-- RLS Policies: chat_messages
-- =============================================================================

drop policy if exists "Sender edita su mensaje" on chat_messages;
create policy "Sender edita su mensaje"
  on chat_messages for update
  using (sender_id = auth.uid());

drop policy if exists "Admin municipal elimina mensajes" on chat_messages;
create policy "Admin municipal elimina mensajes"
  on chat_messages for delete
  using (auth_user_role() = 'municipal_admin');

-- =============================================================================
-- RLS Policies: user_stop_presence
-- =============================================================================

drop policy if exists "Usuario elimina su presencia" on user_stop_presence;
create policy "Usuario elimina su presencia"
  on user_stop_presence for delete
  using (user_id = auth.uid());

drop policy if exists "Admins gestionan presencia" on user_stop_presence;
create policy "Admins gestionan presencia"
  on user_stop_presence for update
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));
