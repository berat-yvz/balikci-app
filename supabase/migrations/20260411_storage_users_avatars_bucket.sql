-- Profil avatarları: Storage bucket + RLS
-- Hata: StorageException Bucket not found (404) → bu migration'ı Supabase SQL Editor'da çalıştırın.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'users-avatars',
  'users-avatars',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 2097152,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Okuma: herkese açık bucket içeriği (public URL ile uyumlu)
DROP POLICY IF EXISTS "users_avatars_public_read" ON storage.objects;
CREATE POLICY "users_avatars_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'users-avatars');

-- Yükleme: yalnızca kendi klasörüne (avatars/{auth.uid()}/...)
DROP POLICY IF EXISTS "users_avatars_insert_own" ON storage.objects;
CREATE POLICY "users_avatars_insert_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'users-avatars'
  AND name LIKE ('avatars/' || auth.uid()::text || '/%')
);

DROP POLICY IF EXISTS "users_avatars_update_own" ON storage.objects;
CREATE POLICY "users_avatars_update_own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'users-avatars'
  AND name LIKE ('avatars/' || auth.uid()::text || '/%')
)
WITH CHECK (
  bucket_id = 'users-avatars'
  AND name LIKE ('avatars/' || auth.uid()::text || '/%')
);

DROP POLICY IF EXISTS "users_avatars_delete_own" ON storage.objects;
CREATE POLICY "users_avatars_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'users-avatars'
  AND name LIKE ('avatars/' || auth.uid()::text || '/%')
);
