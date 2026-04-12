-- ============================================================
-- checkins, users, shops, notifications, shadow_points, weather_cache — RLS
-- Eski projede kullandığınız politikalarla aynı anlam (DROP yok).
--
-- İlişki [supabase_fix_mera_insert.sql] ile:
--   • users: Burada SELECT ("Users visible to all") + UPDATE ("Users can update own profile").
--     INSERT satırı eski kodda yoktu; mera / ensureUserProfile için o dosyadaki
--     "users_insert_own" gerekir — ikisini birlikte kullanın.
--   • "users_select_authenticated" (fix_mera) ile "Users visible to all" birlikte
--     kalırsa ikisi de permissive SELECT olur (çoğu senaryoda sorun olmaz).
-- ============================================================

-- ─── checkins ───

ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkins'
      AND policyname = 'Active checkins visible to all'
  ) THEN
    CREATE POLICY "Active checkins visible to all"
      ON checkins FOR SELECT
      USING (is_active = TRUE);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkins'
      AND policyname = 'Users can insert own checkins'
  ) THEN
    CREATE POLICY "Users can insert own checkins"
      ON checkins FOR INSERT
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkins'
      AND policyname = 'Users can update own checkins'
  ) THEN
    CREATE POLICY "Users can update own checkins"
      ON checkins FOR UPDATE
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ─── users (INSERT fix_mera dosyasında) ───

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
      AND policyname = 'Users visible to all'
  ) THEN
    CREATE POLICY "Users visible to all"
      ON users FOR SELECT
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users'
      AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON users FOR UPDATE
      USING (id = auth.uid());
  END IF;
END $$;

-- ─── shops ───

ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'shops'
      AND policyname = 'Shops visible to all'
  ) THEN
    CREATE POLICY "Shops visible to all"
      ON shops FOR SELECT
      USING (true);
  END IF;
END $$;

-- ─── notifications ───

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users see own notifications'
  ) THEN
    CREATE POLICY "Users see own notifications"
      ON notifications FOR SELECT
      USING (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users update own notifications'
  ) THEN
    CREATE POLICY "Users update own notifications"
      ON notifications FOR UPDATE
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users delete own notifications'
  ) THEN
    CREATE POLICY "Users delete own notifications"
      ON notifications FOR DELETE
      TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;

-- ─── shadow_points ───

ALTER TABLE shadow_points ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'shadow_points'
      AND policyname = 'Users see own shadow points'
  ) THEN
    CREATE POLICY "Users see own shadow points"
      ON shadow_points FOR SELECT
      USING (receiver_id = auth.uid());
  END IF;
END $$;

-- ─── weather_cache ───

ALTER TABLE weather_cache ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'weather_cache'
      AND policyname = 'Weather cache visible to all'
  ) THEN
    CREATE POLICY "Weather cache visible to all"
      ON weather_cache FOR SELECT
      USING (true);
  END IF;
END $$;
