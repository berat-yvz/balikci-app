-- Mera favorileme tablosu
-- Her kullanıcı istediği merayı favorilerine ekleyebilir.
-- Check-in geldiğinde favorileyen kullanıcılara bildirim gönderilir.

CREATE TABLE IF NOT EXISTS spot_favorites (
  user_id    uuid NOT NULL REFERENCES users(id)          ON DELETE CASCADE,
  spot_id    uuid NOT NULL REFERENCES fishing_spots(id)  ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, spot_id)
);

ALTER TABLE spot_favorites ENABLE ROW LEVEL SECURITY;

-- Her kullanıcı yalnızca kendi favorilerini görebilir / düzenleyebilir.
CREATE POLICY "own_favorites" ON spot_favorites
  FOR ALL
  TO authenticated
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- spot_id üzerinde index: getUsersWhoFavorited sorgusu için
CREATE INDEX IF NOT EXISTS idx_spot_favorites_spot_id
  ON spot_favorites (spot_id);
