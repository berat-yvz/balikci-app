-- Profil düzenleme: opsiyonel biyografi alanı.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS bio text;

COMMENT ON COLUMN public.users.bio IS 'Kullanıcının profilde gösterilen kısa tanıtım metni (opsiyonel).';
