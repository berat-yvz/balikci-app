-- Open-Meteo önbelleği — Edge Function: weather-cache (12 kıyı + İstanbul ilçe satırları)
-- Supabase Dashboard > SQL Editor’da çalıştırın.
-- Önkoşul: pg_cron + pg_net; Vault’ta çağrı için JWT (tercihen anon_key).
--
-- Barındırılan Supabase’te ALTER DATABASE ... SET app.service_role_key genelde
-- 42501 verir. Anahtarı Vault’a koyun:
--   SELECT vault.create_secret('eyJ..._ANON_KEY', 'anon_key');
-- Anon ile invoke yetmezse:
--   SELECT vault.create_secret('eyJ..._SERVICE_ROLE', 'service_role_key');
-- ve aşağıda decrypted_secrets sorgusunda name = 'service_role_key' kullanın.
--
-- Eski günde 2 kez çalışan job’ları kaldırmak için (bir kez, gerekirse):
--   SELECT cron.unschedule('weather-cache-morning');
--   SELECT cron.unschedule('weather-cache-afternoon');
--
-- 1) Deploy:  supabase functions deploy weather-cache
-- 2) URL’yi proje Reference ID ile eşleştirin.

SELECT cron.schedule(
  'weather-cache-hourly',
  '0 * * * *',   -- her saat başı UTC (İstanbul saatiyle çakışmaz; saatlik taze veri)
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/weather-cache',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Doğrulama: SELECT * FROM cron.job WHERE jobname = 'weather-cache-hourly';
