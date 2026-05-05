-- shadow_points tablosuna RLS aktif et ve güvenlik politikalarını tanımla
-- Tablo şemada tanımlı ama RLS hiç açılmamış — kritik güvenlik açığı

ALTER TABLE shadow_points ENABLE ROW LEVEL SECURITY;

-- Yalnızca puan alan kullanıcı kendi kayıtlarını görebilir
CREATE POLICY "shadow_points_owner_read"
  ON shadow_points FOR SELECT
  USING (receiver_id = auth.uid());

-- Yalnızca service_role (Edge Function) yazabilir; istemci doğrudan yazamaz
CREATE POLICY "shadow_points_service_only_insert"
  ON shadow_points FOR INSERT
  WITH CHECK (false);

-- Güncelleme ve silme yalnızca service_role ile mümkün
CREATE POLICY "shadow_points_service_only_update"
  ON shadow_points FOR UPDATE
  USING (false);

CREATE POLICY "shadow_points_service_only_delete"
  ON shadow_points FOR DELETE
  USING (false);

-- Sybil saldırısını engelle: aynı kaynak aynı alıcıya yalnızca bir kez gölge puan verebilir
-- (aynı fish_log/checkin için aynı mera sahibine çift puan gitmesin)
ALTER TABLE shadow_points
  ADD CONSTRAINT IF NOT EXISTS uq_shadow_points_source_receiver
  UNIQUE (source_id, receiver_id);

-- Kendi kendine gölge puan kazanmayı engelle
ALTER TABLE shadow_points
  ADD CONSTRAINT IF NOT EXISTS chk_shadow_points_no_self_award
  CHECK (giver_id <> receiver_id);
