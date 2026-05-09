-- ============================================================
-- FAZ 1 — fish_logs → posts veri migrasyonu
--
-- ÖNEMLİ: Bu script 20260509000001_social_feed_posts.sql
-- çalıştırıldıktan SONRA uygulanmalıdır.
--
-- Mevcut fish_logs kayıtları posts tablosuna kopyalanır.
-- fish_logs tablosu bu aşamada KALDIRILMAZ; FAZ 3'te
-- log_list_screen ve ilgili repository'ler kaldırıldıktan
-- sonra DROP TABLE fish_logs çalıştırılabilir.
-- ============================================================

-- Mevcut kayıt sayısını logla (Supabase logs'da izlenebilir)
DO $$
DECLARE
  log_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO log_count FROM fish_logs;
  RAISE NOTICE 'fish_logs → posts migrasyonu başlıyor. Kayıt sayısı: %', log_count;
END;
$$;

-- ─── Migrasyon ────────────────────────────────────────────
-- is_private = TRUE  → visibility = 'private'
-- is_private = FALSE → visibility = 'public'
-- post_type sabit 'catch' (tüm fish_logs av kaydıdır)
-- legacy_fish_log_id → mevcut fish_log.id saklanır (FAZ 2'de referans için)

INSERT INTO posts (
  id,
  user_id,
  spot_id,
  fish_species,
  fish_weight,
  fish_length,
  fish_released,
  photo_url,
  weather_snapshot,
  visibility,
  post_type,
  legacy_fish_log_id,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid()                                    AS id,
  user_id,
  spot_id,
  species                                              AS fish_species,
  weight                                               AS fish_weight,
  length                                               AS fish_length,
  COALESCE(released, FALSE)                            AS fish_released,
  photo_url,
  weather_snapshot,
  CASE WHEN is_private THEN 'private' ELSE 'public' END AS visibility,
  'catch'                                              AS post_type,
  id                                                   AS legacy_fish_log_id,
  created_at,
  created_at                                           AS updated_at
FROM fish_logs
-- Daha önce migrate edilmiş kayıtları tekrar ekleme
WHERE id NOT IN (
  SELECT legacy_fish_log_id FROM posts WHERE legacy_fish_log_id IS NOT NULL
);

-- Migrasyon sonucu özeti
DO $$
DECLARE
  migrated INTEGER;
BEGIN
  SELECT COUNT(*) INTO migrated
  FROM posts
  WHERE legacy_fish_log_id IS NOT NULL;
  RAISE NOTICE 'Migrasyon tamamlandı. posts tablosuna aktarılan kayıt: %', migrated;
END;
$$;
