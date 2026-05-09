-- Balık Günlüğü modülü kaldırıldı — fish_logs tablosu ve ilgili objeler temizlendi
-- NOT: Bu migration'ı çalıştırmadan önce veri yedeği alınması önerilir.

-- posts üzerindeki fish_logs geri referansı (FK önce kaldırılmalı)
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_migrated_from_log_id_fkey;
ALTER TABLE posts DROP COLUMN IF EXISTS migrated_from_log_id;

-- Önce bağımlı trigger'ları kaldır
DROP TRIGGER IF EXISTS on_fish_log_insert ON fish_logs;
DROP TRIGGER IF EXISTS fish_log_score_trigger ON fish_logs;

-- Bağımlı fonksiyonları kaldır (sadece fish_logs'a özel olanlar)
DROP FUNCTION IF EXISTS handle_fish_log_score() CASCADE;

-- shadow_points tablosundan fish_log kaynaklı satırları temizle
DELETE FROM shadow_points WHERE source_type = 'fish_log';

-- fish_logs tablosunu kaldır
DROP TABLE IF EXISTS fish_logs CASCADE;

-- Drift offline cache tablosunu (varsa) kaldırmak için not:
-- LocalFishLog Drift tablosu uygulama tarafında schemaVersion artışıyla kaldırılacak.
