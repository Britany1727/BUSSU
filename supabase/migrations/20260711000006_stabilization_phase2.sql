-- =============================================================================
-- Andes Mobility: Fase 2 de Estabilización — Correcciones Altas
--
-- A10: Agregar detección de departure al trigger de geocerca
-- A11: Activar Storage RLS policies
-- =============================================================================

-- =============================================================================
-- A10: Agregar detección de departure al trigger de geocerca
-- =============================================================================

create or replace function check_stop_geofence()
returns trigger as $$
declare
  nearest record;
  previous_stop_id uuid;
begin
  -- Si el bus no tiene ruta asignada, salir
  if not exists (select 1 from buses where id = new.bus_id and route_id is not null) then
    return new;
  end if;

  -- Buscar la parada más cercana dentro del radio de 30m
  select s.id, s.route_id
  into nearest
  from stops s
  where s.route_id = (select route_id from buses where id = new.bus_id)
    and st_dwithin(s.location, new.location, 30)
  order by st_distance(s.location, new.location)
  limit 1;

  -- A10 FIX: Detectar departure
  -- Obtener la última parada donde el bus fue detectado (arrival sin departure)
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

  -- Si el bus estaba en una parada y ahora NO está en ninguna (salió del radio)
  if previous_stop_id is not null and nearest.id is null then
    insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
    select new.bus_id, previous_stop_id,
           (select id from trips where bus_id = new.bus_id and status = 'active' order by started_at desc limit 1),
           'departure'
    where not exists (
      select 1 from bus_stop_events
      where bus_id = new.bus_id
        and stop_id = previous_stop_id
        and event_type = 'departure'
        and occurred_at > now() - interval '1 minute'
    );
    return new;
  end if;

  -- Si el bus entró a una nueva parada (diferente de la anterior)
  if nearest.id is not null and (previous_stop_id is null or nearest.id != previous_stop_id) then
    -- Si estaba en otra parada, marcar departure de la anterior
    if previous_stop_id is not null then
      insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
      select new.bus_id, previous_stop_id,
             (select id from trips where bus_id = new.bus_id and status = 'active' order by started_at desc limit 1),
             'departure'
      where not exists (
        select 1 from bus_stop_events
        where bus_id = new.bus_id
          and stop_id = previous_stop_id
          and event_type = 'departure'
          and occurred_at > now() - interval '1 minute'
      );
    end if;

    -- Marcar arrival en la nueva parada (con dedup de 5 min)
    insert into bus_stop_events (bus_id, stop_id, trip_id, event_type)
    select new.bus_id, nearest.id,
           (select id from trips where bus_id = new.bus_id and status = 'active' order by started_at desc limit 1),
           'arrival'
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
  for each row execute function check_stop_geofence();

-- =============================================================================
-- A11: Activar Storage RLS policies (antes estaban comentadas)
-- =============================================================================

-- Avatars: lectura pública
drop policy if exists "Avatars públicos" on storage.objects;
create policy "Avatars públicos"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Avatars: usuario sube su propio avatar
drop policy if exists "Usuario sube su avatar" on storage.objects;
create policy "Usuario sube su avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.role() = 'authenticated'
  );

-- Avatars: usuario actualiza/elimina su propio avatar
drop policy if exists "Usuario gestiona su avatar" on storage.objects;
create policy "Usuario gestiona su avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Usuario elimina su avatar" on storage.objects;
create policy "Usuario elimina su avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Documents: solo admins
drop policy if exists "Admins ven documentos" on storage.objects;
create policy "Admins ven documentos"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and auth_user_role() in ('cooperativa_admin', 'municipal_admin')
  );

drop policy if exists "Admins suben documentos" on storage.objects;
create policy "Admins suben documentos"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and auth_user_role() in ('cooperativa_admin', 'municipal_admin')
  );
