-- fish-photos bucket: post yükleme için RLS politikası düzeltmesi
-- Mevcut politika yalnızca fish_logs/{uid}/... yoluna izin veriyor.
-- Yeni create_post_screen.dart {uid}/posts/... formatını kullanıyor → 403 hatası.
--
-- TODO: supabase db push veya Dashboard > SQL Editor'dan bu dosyayı çalıştır.

-- Bucket ayarlarını güncelle (boyut sınırını 5MB'a çıkar)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fish-photos',
  'fish-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public             = true,
  file_size_limit    = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- Çakışabilecek eski politikaları temizle
DROP POLICY IF EXISTS "fish_photos_insert"         ON storage.objects;
DROP POLICY IF EXISTS "fish_photos_select"         ON storage.objects;
DROP POLICY IF EXISTS "fish_photos_update"         ON storage.objects;
DROP POLICY IF EXISTS "fish_photos_delete"         ON storage.objects;
DROP POLICY IF EXISTS "Users can upload fish photos"    ON storage.objects;
DROP POLICY IF EXISTS "Users can view fish photos"      ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own fish photos" ON storage.objects;

-- Herkes görebilir (public bucket — getPublicUrl için gerekli)
CREATE POLICY "fish_photos_select"
ON storage.objects FOR SELECT
USING (bucket_id = 'fish-photos');

-- Authenticated kullanıcı kendi UID klasörüne yükleyebilir: {uid}/posts/...
-- (storage.foldername(name))[1] → ilk klasör segmenti = uid
CREATE POLICY "fish_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'fish-photos'
  AND (
    -- Yeni format: {uid}/posts/{timestamp}.webp
    (storage.foldername(name))[1] = auth.uid()::text
    OR
    -- Eski format (fish_log): fish_logs/{uid}/...  — geriye dönük uyumluluk
    name LIKE ('fish_logs/' || auth.uid()::text || '/%')
  )
);

-- Kendi yüklediğini güncelleyebilir
CREATE POLICY "fish_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'fish-photos'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR name LIKE ('fish_logs/' || auth.uid()::text || '/%')
  )
)
WITH CHECK (
  bucket_id = 'fish-photos'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR name LIKE ('fish_logs/' || auth.uid()::text || '/%')
  )
);

-- Kendi yüklediğini silebilir
CREATE POLICY "fish_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'fish-photos'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR name LIKE ('fish_logs/' || auth.uid()::text || '/%')
  )
);
