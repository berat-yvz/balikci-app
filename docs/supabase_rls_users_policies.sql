-- ============================================================
-- public.users RLS (M-01)
-- Mevcut projede users tablosunda RLS yoksa bu script ekler.
-- Tetikleyici SECURITY DEFINER olduğu için yeni satır insert edilir.
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Mevcut policy isimleriyle çakışırsa önce DROP edin.
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
DROP POLICY IF EXISTS "users_insert_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

-- Liderlik / profil listesi: giriş yapmış herkes okuyabilir (anon key ile uygulama zaten auth kullanıyor)
CREATE POLICY "users_select_authenticated"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

-- İstemci tarafı yedek insert (ensureUserProfile) için
CREATE POLICY "users_insert_own"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
