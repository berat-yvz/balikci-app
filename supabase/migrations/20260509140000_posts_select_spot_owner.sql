-- Gölge puan geçmişi: mera sahibi, kendi merasına bağlı gönderi satırını okuyabilsin.
CREATE POLICY "posts_select_spot_owner"
  ON posts FOR SELECT
  TO authenticated
  USING (
    is_deleted = FALSE
    AND spot_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM fishing_spots fs
      WHERE fs.id = posts.spot_id AND fs.user_id = auth.uid()
    )
  );
