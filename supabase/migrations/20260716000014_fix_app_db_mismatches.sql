-- ============================================================
-- 000014: FIX app-DB column mismatches
-- Agrega columnas faltantes para que la app Flutter conecte
-- correctamente con Supabase.
-- ============================================================

-- =============================================
-- 1. chat_messages: agregar columnas que la app espera
-- =============================================
-- La app usa: room_id, created_at, is_read
-- La DB tiene: conversation_id, sent_at, (no is_read)

-- Renombrar conversation_id → room_id (la app lo usa como 'room_id')
-- NOTA: Si ya hay datos con conversation_id, usar ALTER TABLE rename
DO $$ BEGIN
  ALTER TABLE chat_messages RENAME COLUMN conversation_id TO room_id;
EXCEPTION
  WHEN undefined_column THEN NULL;
  WHEN duplicate_column THEN NULL;
END $$;

-- Renombrar sent_at → created_at
DO $$ BEGIN
  ALTER TABLE chat_messages RENAME COLUMN sent_at TO created_at;
EXCEPTION
  WHEN undefined_column THEN NULL;
  WHEN duplicate_column THEN NULL;
END $$;

-- Agregar is_read si no existe
DO $$ BEGIN
  ALTER TABLE chat_messages ADD COLUMN is_read BOOLEAN DEFAULT false NOT NULL;
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- Actualizar la foreign key de room_id si es necesario
-- (DROP old FK constraint if exists, add new one)
DO $$ BEGIN
  ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_conversation_id_fkey;
  ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_room_id_fkey
    FOREIGN KEY (room_id) REFERENCES chat_conversations(id) ON DELETE CASCADE;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- 2. chat_conversations: agregar columnas que la app espera
-- =============================================
-- La app espera: last_message, last_message_at, unread_count, driver_name, cooperativa_name, is_online

DO $$ BEGIN
  ALTER TABLE chat_conversations ADD COLUMN last_message TEXT DEFAULT '';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE chat_conversations ADD COLUMN last_message_at TIMESTAMPTZ DEFAULT now();
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE chat_conversations ADD COLUMN unread_count INT DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE chat_conversations ADD COLUMN is_online BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Actualizar last_message y last_message_at con datos del último mensaje
UPDATE chat_conversations cc
SET
  last_message = cm.content,
  last_message_at = cm.created_at
FROM chat_messages cm
WHERE cm.room_id = cc.id
  AND cm.created_at = (
    SELECT MAX(created_at) FROM chat_messages WHERE room_id = cc.id
  );

-- =============================================
-- 3. stops: agregar columnas lat/lng generadas
-- =============================================
-- La app espera: lat, lng como columnas directas
-- La DB tiene: location (geography)

DO $$ BEGIN
  ALTER TABLE stops ADD COLUMN lat DOUBLE PRECISION
    GENERATED ALWAYS AS (ST_Y(location::geometry)) STORED;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE stops ADD COLUMN lng DOUBLE PRECISION
    GENERATED ALWAYS AS (ST_X(location::geometry)) STORED;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- =============================================
-- 3b. bus_live_position: agregar route_id para filtrado
-- =============================================
-- La app filtra por route_id en bus_live_position pero no existe
DO $$ BEGIN
  ALTER TABLE bus_live_position ADD COLUMN route_id UUID REFERENCES routes(id);
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Trigger para mantener route_id sincronizado con buses.route_id
CREATE OR REPLACE FUNCTION sync_bus_route_id()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE bus_live_position SET route_id = NEW.route_id WHERE bus_id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_bus_route ON buses;
CREATE TRIGGER trg_sync_bus_route
  AFTER UPDATE OF route_id ON buses
  FOR EACH ROW
  EXECUTE FUNCTION sync_bus_route_id();

-- Poblar route_id existente
UPDATE bus_live_position blp
SET route_id = b.route_id
FROM buses b
WHERE blp.bus_id = b.id AND blp.route_id IS NULL;

-- =============================================
-- 4. routes: crear vista con polyline formateado para la app
-- =============================================
-- La app espera polyline como JSON array [{lat, lng}]
-- PostGIS lo devuelve como GeoJSON coordinates [[lng, lat]]
-- Creamos una vista que formatea correctamente

CREATE OR REPLACE VIEW routes_for_app AS
SELECT
  r.*,
  CASE
    WHEN r.polyline IS NOT NULL THEN
      -- Convertir GeoJSON coordinates a [{lat, lng}]
      (
        SELECT json_agg(json_build_object('lat', coords[2], 'lng', coords[1]))
        FROM (
          SELECT (ST_DumpPoints(r.polyline::geometry)).geom AS point
        ) sub,
        LATERAL (SELECT ST_X(sub.point) AS x, ST_Y(sub.point) AS y) coords_xy,
        LATERAL (SELECT ARRAY[coords_xy.x, coords_xy.y] AS coords) final
      )
    ELSE '[]'::json
  END AS polyline_formatted
FROM routes r;

-- =============================================
-- 5. system_alerts: agregar lat/lng si la app los necesita
-- =============================================
DO $$ BEGIN
  ALTER TABLE system_alerts ADD COLUMN latitude DOUBLE PRECISION;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE system_alerts ADD COLUMN longitude DOUBLE PRECISION;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- =============================================
-- 6. Actualizar las RLS policies de chat_messages con el nuevo nombre
-- =============================================
DROP POLICY IF EXISTS "Chat visible para participantes" ON chat_messages;
CREATE POLICY "Chat visible para participantes"
  ON chat_messages FOR SELECT
  USING (
    sender_id = auth.uid()
    OR room_id IN (
      SELECT id FROM chat_conversations
      WHERE driver_id = auth.uid()
         OR cooperativa_id IN (
           SELECT cooperativa_id FROM profiles WHERE id = auth.uid()
         )
    )
  );

DROP POLICY IF EXISTS "Participantes envian mensajes" ON chat_messages;
CREATE POLICY "Participantes envian mensajes"
  ON chat_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND room_id IN (
      SELECT id FROM chat_conversations
      WHERE driver_id = auth.uid()
         OR cooperativa_id IN (
           SELECT cooperativa_id FROM profiles WHERE id = auth.uid()
         )
    )
  );

DROP POLICY IF EXISTS "Sender edita su mensaje" ON chat_messages;
CREATE POLICY "Sender edita su mensaje"
  ON chat_messages FOR UPDATE
  USING (sender_id = auth.uid());

DROP POLICY IF EXISTS "Admin municipal elimina mensajes" ON chat_messages;
CREATE POLICY "Admin municipal elimina mensajes"
  ON chat_messages FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'municipal_admin'
    )
  );

-- =============================================
-- 7. RPC para obtener conversaciones con datos enriquecidos
-- =============================================
CREATE OR REPLACE FUNCTION get_chat_conversations(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  driver_id UUID,
  cooperativa_id UUID,
  status TEXT,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT,
  driver_name TEXT,
  cooperativa_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cc.id,
    cc.driver_id,
    cc.cooperativa_id,
    cc.status,
    COALESCE(cc.last_message, '') AS last_message,
    cc.last_message_at,
    COALESCE(
      (SELECT COUNT(*) FROM chat_messages cm WHERE cm.room_id = cc.id AND cm.is_read = false AND cm.sender_id != p_user_id),
      0
    ) AS unread_count,
    COALESCE(dp.full_name, 'Conductor') AS driver_name,
    COALESCE(cp.name, 'Cooperativa') AS cooperativa_name
  FROM chat_conversations cc
  LEFT JOIN profiles dp ON dp.id = cc.driver_id
  LEFT JOIN cooperativas cp ON cp.id = cc.cooperativa_id
  WHERE cc.driver_id = p_user_id
     OR cc.cooperativa_id IN (
       SELECT cooperativa_id FROM profiles WHERE id = p_user_id
     )
  ORDER BY cc.last_message_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 8. Trigger para actualizar last_message en chat_conversations
-- =============================================
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_conversations
  SET
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    unread_count = unread_count + 1
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_last_message ON chat_messages;
CREATE TRIGGER trg_update_last_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_last_message();

-- =============================================
-- 9. Realtime para las tablas actualizadas
-- =============================================
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE chat_conversations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE stops;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================
-- 10. Índices para performance
-- =============================================
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_message_at ON chat_conversations(last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_stops_route_id ON stops(route_id);

-- =============================================
-- 11. RPC para actualizar posición GPS del bus
-- =============================================
-- La app escribe lat/lng pero son columnas GENERATED (read-only).
-- Este RPC usa ST_MakePoint para escribir al campo geography correctamente.
CREATE OR REPLACE FUNCTION update_bus_position(
  p_bus_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_speed DOUBLE PRECISION DEFAULT 0,
  p_heading DOUBLE PRECISION DEFAULT 0,
  p_passenger_count INT DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO bus_live_position (bus_id, location, speed_kmh, heading, passenger_count, updated_at)
  VALUES (
    p_bus_id,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    p_speed,
    p_heading,
    p_passenger_count,
    now()
  )
  ON CONFLICT (bus_id) DO UPDATE SET
    location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    speed_kmh = EXCLUDED.speed_kmh,
    heading = EXCLUDED.heading,
    passenger_count = EXCLUDED.passenger_count,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 12. RPC para insertar historial de telemetría
-- =============================================
CREATE OR REPLACE FUNCTION insert_telemetry_history(
  p_bus_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_speed DOUBLE PRECISION DEFAULT 0,
  p_passenger_count INT DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO bus_telemetry_history (bus_id, location, speed_kmh, passenger_count, recorded_at)
  VALUES (
    p_bus_id,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
    p_speed,
    p_passenger_count,
    now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 13. RPC para obtener polyline formateado como la app espera
-- =============================================
CREATE OR REPLACE FUNCTION get_route_polyline(p_route_id UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(json_build_object('lat', coords[2], 'lng', coords[1]))
  INTO result
  FROM (
    SELECT (ST_DumpPoints(r.polyline::geometry)).geom AS point
    FROM routes r WHERE r.id = p_route_id
  ) sub,
  LATERAL (SELECT ST_X(sub.point) AS x, ST_Y(sub.point) AS y) coords_xy,
  LATERAL (SELECT ARRAY[coords_xy.x, coords_xy.y] AS coords) final;

  RETURN COALESCE(result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 14. Fix handle_new_user() - hacer robusto contra errores
-- =============================================
-- El trigger original falla si la tabla profiles tiene constraints
-- que no se cumplen (FK, NOT NULL, RLS). Hacemos que inserte con
-- ON CONFLICT para evitar duplicados.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  raw_role text;
  valid_role user_role;
  v_full_name text;
BEGIN
  raw_role := new.raw_user_meta_data->>'role';
  valid_role := case raw_role
    when 'usuario' then 'usuario'::user_role
    when 'conductor' then 'conductor'::user_role
    when 'cooperativa_admin' then 'cooperativa_admin'::user_role
    when 'municipal_admin' then 'municipal_admin'::user_role
    else 'usuario'::user_role
  end;

  v_full_name := trim(
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'fullName',
      new.email
    )
  );

  INSERT INTO profiles (id, role, full_name, email)
  VALUES (new.id, valid_role, v_full_name, new.email)
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_user error for %: %', new.id, SQLERRM;
  RETURN new;
END;
$$;
