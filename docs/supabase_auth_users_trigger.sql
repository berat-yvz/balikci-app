-- ============================================================
-- auth.users -> public.users otomatik profil (M-01)
-- Supabase SQL Editor'da çalıştırın (auth şemasına tetikleyici).
-- İstemci kayıtta manuel INSERT gerektirmez; e-posta onayı ile uyumludur.
-- ============================================================

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

  -- Benzersiz username: meta veya e-posta öneki + id kısa parça
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
