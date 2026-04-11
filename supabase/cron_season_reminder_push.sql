-- Günlük balık sezonu hatırlatması — Edge Function: season-reminder-push
-- Supabase Dashboard > SQL veya CLI ile çalıştırın.
-- Önkoşul: pg_cron + pg_net; app.service_role_key vault’ta tanımlı olmalı.
--
-- 1) Fonksiyonu deploy:  supabase functions deploy season-reminder-push
-- 2) Aşağıdaki URL’yi kendi proje ref’inizle değiştirin.

SELECT cron.schedule(
  'season-reminder-push',
  '0 7 * * *',   -- 10:00 İstanbul (UTC+3) ≈ 07:00 UTC
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/season-reminder-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Doğrulama: SELECT * FROM cron.job WHERE jobname = 'season-reminder-push';
