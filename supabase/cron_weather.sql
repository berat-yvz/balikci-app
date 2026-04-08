-- Supabase Dashboard > SQL Editor'da çalıştır
-- pg_cron ile günde 2 kez weather-cache Edge Function tetiklenir
-- 06:00 İstanbul = 03:00 UTC, 14:00 İstanbul = 11:00 UTC
--
-- Önkoşul: pg_cron ve pg_net extension'larının aktif olması gerekir.
-- Dashboard > Database > Extensions bölümünden aktif edilebilir.

SELECT cron.schedule(
  'weather-cache-morning',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/weather-cache',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := jsonb_build_object('region', 'istanbul', 'lat', 41.0082, 'lng', 28.9784)
  );
  $$
);

SELECT cron.schedule(
  'weather-cache-afternoon',
  '0 11 * * *',
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/weather-cache',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := jsonb_build_object('region', 'istanbul', 'lat', 41.0082, 'lng', 28.9784)
  );
  $$
);

-- Kayıtlı cron job'ları doğrulamak için:
-- SELECT * FROM cron.job;
