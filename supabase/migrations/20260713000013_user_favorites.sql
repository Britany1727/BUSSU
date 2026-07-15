-- ============================================================
-- 000013: user_favorites table
-- ============================================================

-- Tabla de favoritos del usuario
CREATE TABLE IF NOT EXISTS user_favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('route', 'stop')),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Un usuario no puede tener el mismo favorito dos veces
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_favorites
  ON user_favorites (user_id, item_id, item_type);

-- RLS
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own favorites" ON user_favorites;
CREATE POLICY "Users read own favorites"
  ON user_favorites FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own favorites" ON user_favorites;
CREATE POLICY "Users insert own favorites"
  ON user_favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own favorites" ON user_favorites;
CREATE POLICY "Users delete own favorites"
  ON user_favorites FOR DELETE
  USING (auth.uid() = user_id);

-- Publicar en la replicación en tiempo real (opcional, para sync)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE user_favorites;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
