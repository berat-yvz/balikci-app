-- Aynı kullanıcının aynı meraya aynı gün birden fazla check-in yapmasını engelle
-- Spam ve puan kasma önlemi
CREATE UNIQUE INDEX IF NOT EXISTS idx_checkin_user_spot_daily
  ON checkins (user_id, spot_id, DATE(created_at AT TIME ZONE 'Europe/Istanbul'));

-- Gölge puan sistemi aktif edildiğinde bu kısıt flood saldırısını da engeller
