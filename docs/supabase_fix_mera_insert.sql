-- ============================================================
-- Mera kaydı (fishing_spots INSERT) — birleşik kurulum
-- Önce: public.users ve fishing_spots tabloları mevcut olmalı (supabase_schema.sql).
-- Supabase SQL Editor'da çalıştırın.
--
-- Bu sürüm DROP kullanmaz (Supabase "destructive query" uyarısını tetiklememesi için).
-- Politika / tetikleyici zaten varsa dokunulmaz; tanımı eskiyse Dashboard'dan
-- ilgili policy'yi silip bu scripti yeniden çalıştırın.
--
-- Çözdüğü tipik hatalar:
--  * RLS 42501 fishing_spots → bölüm 3
--  * ensureUserProfile INSERT users → bölüm 2
--  * FK users(id) → bölüm 1 (tetikleyici + backfill)
--
-- Eski projede checkins/shops/notification vb. için kullandığınız RLS:
--   docs/supabase_rls_app_tables.sql (birlikte kullanılabilir).
-- users SELECT: "Users visible to all" orada; burada "users_select_authenticated"
-- ikisi birden kalırsa ikisi de permissive SELECT olur (çoğu senaryoda sorun olmaz).
-- ============================================================

-- ─── BÖLÜM 1: auth.users → public.users (SECURITY DEFINER) ───

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  meta_user text;
  email_local text;
  uname text;
BEGIN
  meta_user := NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), '');
  email_local := SPLIT_PART(COALESCE(NEW.email, 'user'), '@', 1);
  IF email_local IS NULL OR LENGTH(email_local) < 1 THEN
    email_local := 'user';
  END IF;

  uname := COALESCE(meta_user, email_local);
  uname := LEFT(REGEXP_REPLACE(uname, '[^a-zA-Z0-9_]', '_', 'g'), 16);
  IF LENGTH(uname) < 3 THEN
    uname := 'user';
  END IF;

  uname := uname || '_' || LEFT(REPLACE(NEW.id::text, '-', ''), 8);

  INSERT INTO public.users (id, email, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, uname || '@placeholder.local'),
    uname
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE t.tgname = 'on_auth_user_created'
      AND n.nspname = 'auth'
      AND c.relname = 'users'
  ) THEN
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION public.handle_new_user();
  END IF;
END $$;

-- Mevcut oturumlar: auth’ta var, public.users’ta yoksa
INSERT INTO public.users (id, email, username)
SELECT
  au.id,
  COALESCE(au.email, 'user_' || LEFT(REPLACE(au.id::text, '-', ''), 8) || '@placeholder.local'),
  'user_' || LEFT(REPLACE(au.id::text, '-', ''), 8)
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = au.id)
ON CONFLICT (id) DO NOTHING;

-- ─── BÖLÜM 2: public.users RLS (ensureUserProfile INSERT için) ───

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_select_authenticated'
  ) THEN
    CREATE POLICY "users_select_authenticated"
      ON public.users FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_insert_own'
  ) THEN
    CREATE POLICY "users_insert_own"
      ON public.users FOR INSERT
      TO authenticated
      WITH CHECK (id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_update_own'
  ) THEN
    CREATE POLICY "users_update_own"
      ON public.users FOR UPDATE
      TO authenticated
      USING (id = auth.uid())
      WITH CHECK (id = auth.uid());
  END IF;
END $$;

-- ─── BÖLÜM 3: fishing_spots yazma RLS ───

ALTER TABLE fishing_spots ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
      AND tablename = 'fishing_spots'
      AND policyname = 'Authenticated insert own fishing_spots'
  ) THEN
    CREATE POLICY "Authenticated insert own fishing_spots"
      ON fishing_spots FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
      AND tablename = 'fishing_spots'
      AND policyname = 'Authenticated update own fishing_spots'
  ) THEN
    CREATE POLICY "Authenticated update own fishing_spots"
      ON fishing_spots FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
      AND tablename = 'fishing_spots'
      AND policyname = 'Authenticated delete own fishing_spots'
  ) THEN
    CREATE POLICY "Authenticated delete own fishing_spots"
      ON fishing_spots FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;
