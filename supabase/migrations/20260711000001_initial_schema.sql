-- =============================================================================
-- Andes Mobility: Migración inicial de base de datos
-- Supabase + PostgreSQL 15 + PostGIS
-- =============================================================================

-- 1. EXTENSIONES
-- =============================================================================
create extension if not exists "uuid-ossp";
create extension if not exists postgis;

-- 2. TIPOS ENUM
-- =============================================================================
do $$ begin
  create type user_role as enum (
    'usuario',
    'conductor',
    'cooperativa_admin',
    'municipal_admin'
  );
exception when duplicate_object then null;
end $$;

-- 3. TABLAS PRINCIPALES
-- =============================================================================

-- 3.1 Cooperativas (creada antes que profiles por FK)
create table if not exists cooperativas (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  ruc text unique,
  status text not null default 'active'
    check (status in ('active', 'suspended', 'inactive')),
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3.2 Perfiles de usuario
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

-- 3.3 Conductores
create table if not exists drivers (
  id uuid primary key references profiles(id) on delete cascade,
  cooperativa_id uuid references cooperativas(id) on delete set null,
  license_number text,
  assigned_bus_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 3.4 Rutas (con PostGIS)
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

-- 3.5 Buses
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

-- FK de drivers.assigned_bus_id
do $$ begin
  alter table drivers
    add constraint fk_drivers_assigned_bus
    foreign key (assigned_bus_id) references buses(id) on delete set null;
exception when duplicate_object then null;
end $$;

-- 3.6 Paradas (con PostGIS)
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

-- Índice espacial para búsqueda de paradas cercanas
create index if not exists idx_stops_location
  on stops using gist(location);

-- 3.7 Posición de buses en tiempo real
create table if not exists bus_live_position (
  bus_id uuid primary key references buses(id) on delete cascade,
  location geography(point, 4326),
  speed_kmh double precision,
  heading double precision,
  passenger_count int not null default 0,
  occupancy_pct double precision default 0,
  updated_at timestamptz not null default now()
);

-- Trigger para calcular occupancy_pct automáticamente
create or replace function calc_occupancy_pct()
returns trigger as $$
declare
  bus_capacity int;
begin
  select capacity into bus_capacity from buses where buses.id = new.bus_id;
  if bus_capacity is null or bus_capacity = 0 then
    new.occupancy_pct := 0;
  else
    new.occupancy_pct := least(100, round(
      (new.passenger_count::double precision / bus_capacity * 100)::numeric, 1
    ));
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_calc_occupancy on bus_live_position;
create trigger trg_calc_occupancy
  before insert or update of passenger_count
  on bus_live_position
  for each row execute function calc_occupancy_pct();

-- 3.8 Historial de telemetría
create table if not exists bus_telemetry_history (
  id bigint generated always as identity primary key,
  bus_id uuid references buses(id) on delete cascade,
  location geography(point, 4326),
  speed_kmh double precision,
  passenger_count int not null default 0,
  recorded_at timestamptz not null default now()
);

create index if not exists idx_telemetry_bus_time
  on bus_telemetry_history(bus_id, recorded_at desc);

-- 3.9 Viajes
create table if not exists trips (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid references buses(id) on delete set null,
  route_id uuid references routes(id) on delete set null,
  driver_id uuid references drivers(id) on delete set null,
  started_at timestamptz,
  ended_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'active', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

-- 3.10 Eventos de parada (llegada/salida)
create table if not exists bus_stop_events (
  id uuid primary key default gen_random_uuid(),
  bus_id uuid references buses(id) on delete cascade,
  stop_id uuid references stops(id) on delete cascade,
  trip_id uuid references trips(id) on delete cascade,
  event_type text not null check (event_type in ('arrival', 'departure')),
  occurred_at timestamptz not null default now()
);

-- 3.11 Presencia de usuario en parada (BLE)
create table if not exists user_stop_presence (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  stop_id uuid references stops(id) on delete cascade,
  detected_at timestamptz not null default now()
);

-- 3.12 Solicitudes de parada (conductores)
create table if not exists stop_requests (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid references drivers(id) on delete cascade,
  proposed_lat double precision not null,
  proposed_lng double precision not null,
  justification text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- 3.13 Alertas del sistema
create table if not exists system_alerts (
  id uuid primary key default gen_random_uuid(),
  scope text not null default 'system'
    check (scope in ('route', 'stop', 'system')),
  severity text not null default 'low'
    check (severity in ('low', 'medium', 'high')),
  title text not null,
  description text,
  route_id uuid references routes(id) on delete set null,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- 3.14 Suscripciones Premium
create table if not exists premium_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  plan_id text not null default 'premium_mensual',
  status text not null default 'active'
    check (status in ('active', 'cancelled', 'expired')),
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  payment_ref text,
  created_at timestamptz not null default now()
);

-- 3.15 Chat
create table if not exists chat_conversations (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid references drivers(id) on delete cascade,
  cooperativa_id uuid references cooperativas(id) on delete cascade,
  status text not null default 'open'
    check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists chat_messages (
  id bigint generated always as identity primary key,
  conversation_id uuid references chat_conversations(id) on delete cascade,
  sender_id uuid references profiles(id) on delete cascade,
  content text not null,
  sent_at timestamptz not null default now()
);

-- 3.16 Device tokens (push notifications)
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade unique,
  token text not null,
  platform text not null default 'unknown',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
