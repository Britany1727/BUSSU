-- =============================================================================
-- Andes Mobility: IoT Tables - Bridge, Device Registry, Logs, Queue
-- =============================================================================

-- 13. Registro de dispositivos IoT
create table if not exists device_registry (
  device_id text primary key,
  bus_id uuid references buses(id) on delete cascade,
  firmware_version text,
  hardware_model text not null default 'ESP32-C3',
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  status text not null default 'online'
    check (status in ('online', 'offline', 'error', 'maintenance')),
  consecutive_failures int not null default 0,
  metadata jsonb default '{}',
  created_at timestamptz not null default now()
);

-- 14. Logs del puente MQTT
create table if not exists bridge_logs (
  id bigint generated always as identity primary key,
  instance_id text not null,
  level text not null check (level in ('info', 'warn', 'error')),
  message text not null,
  metadata jsonb default '{}',
  created_at timestamptz not null default now()
);

create index if not exists idx_bridge_logs_time
  on bridge_logs(created_at desc);
create index if not exists idx_bridge_logs_level
  on bridge_logs(level, created_at desc);

-- 15. Métricas del puente
create table if not exists bridge_metrics (
  id bigint generated always as identity primary key,
  instance_id text not null,
  uptime_seconds int not null default 0,
  messages_processed bigint not null default 0,
  errors bigint not null default 0,
  connected_devices int not null default 0,
  recorded_at timestamptz not null default now()
);

create index if not exists idx_bridge_metrics_time
  on bridge_metrics(recorded_at desc);

-- 16. Cola de telemetría offline
create table if not exists telemetry_offline_queue (
  id bigint generated always as identity primary key,
  bus_id uuid references buses(id) on delete cascade,
  payload jsonb not null,
  enqueued_at timestamptz not null default now(),
  processed boolean not null default false,
  retries int not null default 0,
  processed_at timestamptz
);

create index if not exists idx_offline_queue_pending
  on telemetry_offline_queue(processed, retries)
  where processed = false and retries < 5;

-- 17. Health del puente (topic bridge/health)
create table if not exists bridge_health (
  instance_id text primary key,
  status text not null default 'healthy'
    check (status in ('healthy', 'degraded', 'error', 'unknown')),
  uptime_seconds int not null default 0,
  messages_processed bigint not null default 0,
  errors bigint not null default 0,
  connected_devices int not null default 0,
  last_heartbeat timestamptz not null default now()
);

-- Realtime para monitoreo
do $$ begin alter publication supabase_realtime add table bridge_health; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table device_registry; exception when duplicate_object then null; end $$;

-- RLS para IoT tables
alter table device_registry enable row level security;
alter table bridge_logs enable row level security;
alter table bridge_metrics enable row level security;
alter table telemetry_offline_queue enable row level security;
alter table bridge_health enable row level security;

-- Solo admins y service_role acceden a datos IoT
drop policy if exists "Admins ven device registry" on device_registry;
create policy "Admins ven device registry"
  on device_registry for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Service role gestiona device registry" on device_registry;
create policy "Service role gestiona device registry"
  on device_registry for all
  using (true);

drop policy if exists "Admins ven bridge health" on bridge_health;
create policy "Admins ven bridge health"
  on bridge_health for select
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Admins ven bridge logs" on bridge_logs;
create policy "Admins ven bridge logs"
  on bridge_logs for select
  using (auth_user_role() = 'municipal_admin');

-- Función RPC: estado consolidado de dispositivos por cooperativa
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
  order by dr.last_seen desc;
$$;

-- Función RPC: health check del puente (últimos 5 minutos)
create or replace function get_bridge_status()
returns table (
  instance_id text,
  status text,
  uptime_hours double precision,
  messages_per_minute double precision,
  error_rate double precision,
  connected_devices int,
  last_heartbeat timestamptz
) language sql stable as $$
  select
    instance_id,
    status,
    round(uptime_seconds::numeric / 3600, 2) as uptime_hours,
    round(messages_processed::numeric / greatest(uptime_seconds / 60, 1), 1) as messages_per_minute,
    round(
      case when (messages_processed + errors) = 0 then 0
      else errors::numeric / (messages_processed + errors) * 100
      end, 2
    ) as error_rate,
    connected_devices,
    last_heartbeat
  from bridge_health
  where last_heartbeat > now() - interval '5 minutes'
  order by last_heartbeat desc;
$$;
