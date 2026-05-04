-- fish-photos bucket'ına MIME tipi kısıtlaması ekle
-- Güvenlik açığı: allowed_mime_types NULL iken herhangi bir dosya türü yüklenebiliyordu
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
WHERE id = 'fish-photos';
