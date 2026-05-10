-- Gölge Puan Faz 2: kısıtlar, indeksler, checkins günlük tekil indeksi
-- Not: PostgreSQL'de DATE(ts) yok; İstanbul günü için (ts AT TIME ZONE 'Europe/Istanbul')::date kullanıldı.

-- 2A: Kolonlar (zaten varsa dokunulmaz) ve varsayılan kaynak tipi
ALTER TABLE shadow_points
  ADD COLUMN IF NOT EXISTS source_type TEXT,
  ADD COLUMN IF NOT EXISTS source_id UUID;

ALTER TABLE shadow_points ALTER COLUMN source_type SET DEFAULT 'post';

-- 2B: Kaynak + alıcı başına tek kayıt
ALTER TABLE shadow_points DROP CONSTRAINT IF EXISTS uq_shadow_points_source_receiver;
ALTER TABLE shadow_points
  ADD CONSTRAINT uq_shadow_points_source_receiver UNIQUE (source_id, receiver_id);

-- 2C: Kendine gölge puanı engeli
ALTER TABLE shadow_points DROP CONSTRAINT IF EXISTS chk_shadow_points_no_self_award;
ALTER TABLE shadow_points
  ADD CONSTRAINT chk_shadow_points_no_self_award CHECK (giver_id <> receiver_id);

-- 2D: Sorgu indeksleri
CREATE INDEX IF NOT EXISTS idx_shadow_points_receiver ON shadow_points (receiver_id);
CREATE INDEX IF NOT EXISTS idx_shadow_points_source ON shadow_points (source_id);

-- 2F: Aynı gün aynı nokta için fazla check-in kayıtlarını tekilleştir (id küçük olan kalır)
DELETE FROM checkins c1 USING checkins c2
WHERE c1.id > c2.id
  AND c1.user_id = c2.user_id
  AND c1.spot_id = c2.spot_id
  AND (c1.created_at AT TIME ZONE 'Europe/Istanbul')::date
    = (c2.created_at AT TIME ZONE 'Europe/Istanbul')::date;

CREATE UNIQUE INDEX IF NOT EXISTS idx_checkin_user_spot_daily
  ON checkins (user_id, spot_id, ((created_at AT TIME ZONE 'Europe/Istanbul')::date));

-- RLS ve politikalar
ALTER TABLE shadow_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own shadow points" ON shadow_points;

CREATE POLICY "shadow_points_select_own"
  ON shadow_points FOR SELECT TO authenticated
  USING (receiver_id = auth.uid());

DROP POLICY IF EXISTS "shadow_points_service_only_insert" ON shadow_points;
CREATE POLICY "shadow_points_service_only_insert"
  ON shadow_points FOR INSERT TO authenticated
  WITH CHECK (false);

DROP POLICY IF EXISTS "shadow_points_service_only_update" ON shadow_points;
CREATE POLICY "shadow_points_service_only_update"
  ON shadow_points FOR UPDATE TO authenticated
  USING (false);

DROP POLICY IF EXISTS "shadow_points_service_only_delete" ON shadow_points;
CREATE POLICY "shadow_points_service_only_delete"
  ON shadow_points FOR DELETE TO authenticated
  USING (false);
