-- Sabah 06:00 İstanbul saati (UTC+3 → 03:00 UTC) hava bildirimi cron job'ı
-- Supabase Dashboard > SQL Editor'da çalıştır.
-- Önkoşul: pg_cron ve pg_net extension'ları aktif olmalı.
--
-- Bu job her sabah aktif kullanıcılara (son 30 günde giriş yapan) hava
-- bildirimini morning-weather-push Edge Function üzerinden gönderir.

-- ── Edge Function: morning-weather-push ──────────────────────────────────────
-- Henüz deploy edilmemişse önce bu fonksiyonu deploy et:
--   supabase functions deploy morning-weather-push
-- Bu SQL yalnızca tetikleyiciyi zamanlar; asıl mantık Edge Function'da.

SELECT cron.schedule(
  'morning-weather-push',
  '0 3 * * *',   -- 06:00 İstanbul = 03:00 UTC
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/morning-weather-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Doğrulama:
-- SELECT * FROM cron.job WHERE jobname = 'morning-weather-push';
