-- ============================================================
-- FAZ 1 — fish_logs → posts veri migrasyonu
-- Çalıştırma sırası: 3/3  (20260509000001–02 önce çalışmalı)
--
-- Yalnızca public (is_private=FALSE) ve fotoğraflı kayıtlar
-- taşınır; fotoğrafsız veya gizli kayıtlar atlanır.
--
-- fish_logs tablosu bu aşamada KALDIRILMAZ.
-- FAZ 3 tamamlanıp log_list_screen + fish_log_repository
-- kaldırıldıktan sonra ayrı bir migration ile DROP edilir.
-- ============================================================

-- Migrasyon öncesi kayıt sayısı (Supabase logs'da izlenebilir)
DO $$
DECLARE
  source_count INTEGER;
  eligible_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO source_count FROM fish_logs;
  SELECT COUNT(*) INTO eligible_count
  FROM fish_logs
  WHERE is_private = FALSE AND photo_url IS NOT NULL;

  RAISE NOTICE 'Toplam fish_logs: %, Taşınacak (public + fotoğraflı): %',
    source_count, eligible_count;
END;
$$;

-- ─── Migrasyon ────────────────────────────────────────────

INSERT INTO posts (
  id,
  user_id,
  photo_url,
  caption,
  fish_species,
  spot_id,
  spot_privacy_snapshot,
  spot_district,
  migrated_from_log_id,
  is_deleted,
  created_at
)
SELECT
  gen_random_uuid()                                             AS id,
  fl.user_id,
  fl.photo_url,
  NULL                                                          AS caption,
  ARRAY[fl.species]                                             AS fish_species,
  fl.spot_id,
  -- Mevcut meranın gizlilik seviyesini snapshot'la;
  -- mera silinmişse 'public' varsayılanına düş
  COALESCE(fs.privacy_level, 'public')                         AS spot_privacy_snapshot,
  NULL                                                          AS spot_district, -- FAZ 2'de ilçe çözümleyici ile doldurulabilir
  fl.id                                                         AS migrated_from_log_id,
  FALSE                                                         AS is_deleted,
  fl.created_at
FROM fish_logs fl
LEFT JOIN fishing_spots fs ON fs.id = fl.spot_id
WHERE fl.is_private = FALSE
  AND fl.photo_url IS NOT NULL
  -- İdempotent: daha önce migrate edilen kayıtları tekrar ekleme
  AND fl.id NOT IN (
    SELECT migrated_from_log_id
    FROM posts
    WHERE migrated_from_log_id IS NOT NULL
  );

-- Migrasyon sonuç özeti
DO $$
DECLARE
  migrated INTEGER;
BEGIN
  SELECT COUNT(*) INTO migrated
  FROM posts
  WHERE migrated_from_log_id IS NOT NULL;
  RAISE NOTICE 'Migrasyon tamamlandı. posts tablosuna aktarılan kayıt: %', migrated;
END;
$$;
