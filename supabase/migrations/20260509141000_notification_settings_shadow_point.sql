-- Gölge puan push/in-app bildirimi için kullanıcı tercihi
ALTER TABLE notification_settings
  ADD COLUMN IF NOT EXISTS shadow_point BOOLEAN NOT NULL DEFAULT TRUE;
