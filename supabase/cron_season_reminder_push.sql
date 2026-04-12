-- Günlük balık sezonu hatırlatması — Edge Function: season-reminder-push
-- Supabase Dashboard > SQL Editor’da çalıştırın.
-- Önkoşul: pg_cron + pg_net; Vault’ta çağrı için JWT (tercihen anon_key).
--
-- Barındırılan Supabase’te ALTER DATABASE ... SET app.service_role_key genelde
-- 42501 verir (postgres rolü süper kullanıcı değil). Anahtarı Vault’a koyun:
--   SELECT vault.create_secret('eyJ..._ANON_KEY', 'anon_key');
-- Anon ile invoke yetmezse (nadir):
--   SELECT vault.create_secret('eyJ..._SERVICE_ROLE', 'service_role_key');
-- ve aşağıda decrypted_secrets sorgusunda name = 'service_role_key' kullanın.
--
-- 1) Fonksiyonu deploy:  supabase functions deploy season-reminder-push
-- 2) URL’yi Project Settings > General > Reference ID ile eşleştirin.

SELECT cron.schedule(
  'season-reminder-push',
  '0 7 * * *',   -- 10:00 İstanbul (UTC+3) ≈ 07:00 UTC
  $$
  SELECT net.http_post(
    url := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/season-reminder-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'anon_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Doğrulama: SELECT * FROM cron.job WHERE jobname = 'season-reminder-push';
