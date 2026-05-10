-- Open-Meteo önbelleği — Edge Function: weather-cache (12 kıyı + İstanbul ilçe satırları)
-- Supabase Dashboard > SQL Editor'da çalıştırın.
--
-- Akış: Her saat **:00** cron bu Edge'i çağırır → Open-Meteo'dan veri çekilip `weather_cache` dolar.
-- Flutter istemci **:02** (İstanbul yerel) `weather_cache` okur (işlem bitsin diye 2 dk pay).
--
-- Önkoşul: pg_cron + pg_net etkin olmalı.
-- Vault'a sırlar şöyle eklenir:
--   SELECT vault.create_secret('eyJ..._ANON_KEY',      'anon_key');
--   SELECT vault.create_secret('eyJ..._SERVICE_ROLE',  'service_role_key');
--   SELECT vault.create_secret('gizli-deger',          'webhook_secret');
--
-- Eski cron job'ları kaldırmak için (gerekirse):
--   SELECT cron.unschedule('weather-cache-morning');
--   SELECT cron.unschedule('weather-cache-afternoon');
--   SELECT cron.unschedule('weather-cache-hourly');
--
-- 1) Deploy:  supabase functions deploy weather-cache
-- 2) Bu dosyayı Dashboard > SQL Editor'da çalıştır.

-- Mevcut job'u güncelle (INSERT OR UPDATE):
SELECT cron.unschedule('weather-cache-hourly') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'weather-cache-hourly'
);

SELECT cron.schedule(
  'weather-cache-hourly',
  '0 * * * *',   -- her saat başı Open-Meteo → weather_cache
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/weather-cache',
    headers := jsonb_build_object(
      'Content-Type',    'application/json',
      'Authorization',   'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key'),
      'x-webhook-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'webhook_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Doğrulama:
-- SELECT * FROM cron.job WHERE jobname = 'weather-cache-hourly';
