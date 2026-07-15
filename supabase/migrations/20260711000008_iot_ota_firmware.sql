-- =============================================================================
-- Andes Mobility: IoT OTA + Firmware Management
-- =============================================================================

-- 18. Versiones de firmware registradas
create table if not exists firmware_versions (
  id uuid primary key default gen_random_uuid(),
  hardware_model text not null default 'ESP32-C3',
  version text not null,
  binary_url text not null,
  checksum_sha256 text not null,
  release_notes text,
  min_hardware_version text,
  is_active boolean not null default true,
  uploaded_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique(hardware_model, version)
);

create index if not exists idx_firmware_model_active
  on firmware_versions(hardware_model, is_active)
  where is_active = true;

-- 19. Comandos OTA pendientes
create table if not exists ota_commands (
  id uuid primary key default gen_random_uuid(),
  device_id text not null references device_registry(device_id),
  target_version text not null,
  status text not null default 'pending'
    check (status in ('pending', 'downloading', 'installing', 'completed', 'failed', 'cancelled')),
  command_sent_at timestamptz,
  download_started_at timestamptz,
  completed_at timestamptz,
  error_message text,
  retries int not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);

create index if not exists idx_ota_device_status
  on ota_commands(device_id, status)
  where status in ('pending', 'downloading', 'installing');

-- 20. Actualizar firmware_version en device_registry tras OTA exitoso
create or replace function update_device_firmware_on_ota()
returns trigger as $$
begin
  if new.status = 'completed' then
    update device_registry
    set firmware_version = new.target_version,
        last_seen = now()
    where device_id = new.device_id;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_ota_completed on ota_commands;
create trigger trg_ota_completed
  after update on ota_commands
  for each row
  when (new.status = 'completed')
  execute function update_device_firmware_on_ota();

-- 21. RPC: Obtener OTA pendientes para un dispositivo
create or replace function get_pending_ota(device_id_param text)
returns table (
  command_id uuid,
  target_version text,
  binary_url text,
  checksum_sha256 text
) language sql stable as $$
  select
    oc.id,
    oc.target_version,
    fv.binary_url,
    fv.checksum_sha256
  from ota_commands oc
  join firmware_versions fv
    on fv.version = oc.target_version
    and fv.hardware_model = 'ESP32-C3'
  where oc.device_id = device_id_param
    and oc.status = 'pending'
  order by oc.created_at asc
  limit 1;
$$;

-- 22. RLS para firmware y OTA
alter table firmware_versions enable row level security;
alter table ota_commands enable row level security;

drop policy if exists "Admins gestionan firmware" on firmware_versions;
create policy "Admins gestionan firmware"
  on firmware_versions for all
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Todos ven firmware activo" on firmware_versions;
create policy "Todos ven firmware activo"
  on firmware_versions for select
  using (is_active = true);

drop policy if exists "Admins gestionan OTA" on ota_commands;
create policy "Admins gestionan OTA"
  on ota_commands for all
  using (auth_user_role() in ('cooperativa_admin', 'municipal_admin'));

drop policy if exists "Service role ejecuta OTA" on ota_commands;
create policy "Service role ejecuta OTA"
  on ota_commands for update
  using (auth.role() = 'service_role');

-- 23. Realtime para OTA commands
do $$ begin alter publication supabase_realtime add table ota_commands; exception when duplicate_object then null; end $$;

-- 24. Seed: firmware inicial
insert into firmware_versions (hardware_model, version, binary_url, checksum_sha256, release_notes)
values (
  'ESP32-C3',
  '1.0.0',
  'https://storage.andesmobility.com/firmware/esp32-c3/v1.0.0.bin',
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  'Versión inicial: GPS NEO-6M, sensor IR VL53L0X, MQTT TLS, HMAC-SHA256, buffer offline 100 mensajes, WiFi reconnect.'
) on conflict (hardware_model, version) do nothing;
