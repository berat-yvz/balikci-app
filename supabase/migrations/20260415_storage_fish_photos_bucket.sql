-- Balık günlüğü fotoğrafları: fish-photos bucket + RLS
-- Uygulama: fish_logs/{auth.uid()}/... (lib/features/fish_log/...)
-- Dashboard'da tek policy / private bucket → yükleme veya public URL ile okuma başarısız olabilir.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fish-photos',
  'fish-photos',
  true,
  2097152,
  NULL
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = COALESCE(EXCLUDED.file_size_limit, 2097152);

-- Okuma: public URL (getPublicUrl) ile uyumlu — bucket public kalmalı
DROP POLICY IF EXISTS "fish_photos_public_read" ON storage.objects;
CREATE POLICY "fish_photos_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'fish-photos');

-- Yükleme / güncelleme / silme: yalnızca kendi fish_logs klasörü
DROP POLICY IF EXISTS "fish_photos_insert_own_fish_logs" ON storage.objects;
CREATE POLICY "fish_photos_insert_own_fish_logs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'fish-photos'
  AND name LIKE ('fish_logs/' || auth.uid()::text || '/%')
);

DROP POLICY IF EXISTS "fish_photos_update_own_fish_logs" ON storage.objects;
CREATE POLICY "fish_photos_update_own_fish_logs"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'fish-photos'
  AND name LIKE ('fish_logs/' || auth.uid()::text || '/%')
)
WITH CHECK (
  bucket_id = 'fish-photos'
  AND name LIKE ('fish_logs/' || auth.uid()::text || '/%')
);

DROP POLICY IF EXISTS "fish_photos_delete_own_fish_logs" ON storage.objects;
CREATE POLICY "fish_photos_delete_own_fish_logs"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'fish-photos'
  AND name LIKE ('fish_logs/' || auth.uid()::text || '/%')
);
