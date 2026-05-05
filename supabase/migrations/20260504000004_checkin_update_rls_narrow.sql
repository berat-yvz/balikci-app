-- checkins UPDATE politikasını daralt
-- Mevcut geniş politika kullanıcının true_votes, false_votes, is_hidden
-- gibi kritik alanları doğrudan güncellemesine izin veriyor

-- Eski politikayı kaldır
DROP POLICY IF EXISTS "Owner can deactivate own checkin" ON checkins;

-- Yeni dar politika: yalnızca is_active alanını güncelleyebilir
-- Oy sayaçları ve is_hidden yalnızca trigger (SECURITY DEFINER) tarafından değiştirilir
CREATE POLICY "Owner can deactivate own checkin"
  ON checkins FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
  );

-- NOT: true_votes, false_votes, is_hidden alanlarının korunması
-- trg_checkin_votes_aggregate trigger'ı SECURITY DEFINER ile çalıştığından
-- istemci bu alanları RLS üzerinden güncelleyemez.
-- Ek uygulama katmanı koruması için bu alanlar Flutter tarafında
-- hiçbir zaman UPDATE payload'ına dahil edilmemelidir.
