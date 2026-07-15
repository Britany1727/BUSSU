-- =============================================================================
-- Andes Mobility: Fix telemetría — exponer lat/lng planos para Realtime
--
-- Problema: bus_live_position y bus_telemetry_history solo tienen la columna
-- `location` (geography). El puente MQTT escribe bien (usa WKT), pero:
--   - ObdTelemetryDataSourceImpl (Flutter, conductor) escribía lat/lng planos
--     que no existen como columnas → los inserts fallaban silenciosamente.
--   - BusModel.fromRealtime() espera json['lat']/json['lng'] planos, pero
--     Realtime solo puede enviar lo que existe como columna.
--
-- Fix: agregar columnas GENERATED que derivan lat/lng desde `location`.
-- Así Realtime las incluye automáticamente sin cambiar el tipo geography
-- (se conservan los índices espaciales y las funciones PostGIS existentes).
-- =============================================================================

alter table bus_live_position
  add column if not exists lat double precision
    generated always as (ST_Y(location::geometry)) stored,
  add column if not exists lng double precision
    generated always as (ST_X(location::geometry)) stored;

alter table bus_telemetry_history
  add column if not exists lat double precision
    generated always as (ST_Y(location::geometry)) stored,
  add column if not exists lng double precision
    generated always as (ST_X(location::geometry)) stored;

-- =============================================================================
-- Código legible para paradas
--
-- El ESP32-C3 no maneja UUIDs (son muy largos para un microcontrolador).
-- Agregamos un campo `code` a la tabla `stops` para que el firmware use
-- un identificador corto como "PARADA_001", "MI_PARADA", etc.
-- =============================================================================

alter table stops
  add column if not exists code text unique;

-- =============================================================================
-- Eventos de llegada a parada, reportados directamente por el ESP32-C3
--
-- El ESP32-C3 de la parada NO pasa por el puente MQTT/HMAC (ese circuito es
-- para telemetría OBD/hardware embarcado en el bus). El ESP32-C3 de parada
-- inserta directo vía REST con la anon key, igual que el resto del MVP.
-- La policy de insert es intencionalmente permisiva para el MVP: solo
-- requiere que bus_id y stop_id existan (constraint FK ya lo garantiza).
-- =============================================================================

alter table bus_stop_events enable row level security;

drop policy if exists "Lectura pública de eventos de parada" on bus_stop_events;
create policy "Lectura pública de eventos de parada"
  on bus_stop_events for select
  using (true);

drop policy if exists "ESP32-C3 inserta eventos de llegada" on bus_stop_events;
create policy "ESP32-C3 inserta eventos de llegada"
  on bus_stop_events for insert
  with check (event_type in ('arrival', 'departure'));

do $$ begin alter publication supabase_realtime add table bus_stop_events; exception when duplicate_object then null; end $$;

-- =============================================================================
-- RPC: reporte de llegada desde el ESP32-C3
--
-- Acepta un `stop_code` legible (ej: "PARADA_001") en vez de UUID.
-- La función resuelve internamente el código a UUID y la placa del bus
-- a bus_id, registrando el evento en una sola llamada HTTP.
-- =============================================================================

-- Eliminar la versión anterior que aceptaba UUID
drop function if exists report_stop_arrival(uuid, text, int);

create or replace function report_stop_arrival(
  stop_code_param text,
  bus_plate_param text,
  rssi_param int default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_stop_id uuid;
  resolved_bus_id uuid;
  event_id uuid;
begin
  -- Resolver código de parada a UUID
  select id into resolved_stop_id from stops where code = stop_code_param;

  if resolved_stop_id is null then
    raise exception 'Parada con código % no encontrada', stop_code_param;
  end if;

  -- Resolver placa de bus a UUID
  select id into resolved_bus_id from buses where plate = bus_plate_param;

  if resolved_bus_id is null then
    raise exception 'Bus con placa % no encontrado', bus_plate_param;
  end if;

  insert into bus_stop_events (bus_id, stop_id, event_type)
  values (resolved_bus_id, resolved_stop_id, 'arrival')
  returning id into event_id;

  return event_id;
end;
$$;

-- Permite ejecutar la función con la anon key (el ESP32-C3 no tiene service_role)
grant execute on function report_stop_arrival(text, text, int) to anon;
