-- pg_cron extension aktif olduğundan emin ol
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Mevcut cron job'ları kontrol et ve eksik olanları kaydet
-- weather-cache: her saat başı çalışır
SELECT cron.schedule(
  'weather-cache-hourly',
  '0 * * * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/weather-cache',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', current_setting('app.webhook_secret', true)
      ),
      body := '{}'::jsonb
    );
  $$
) ON CONFLICT (jobname) DO NOTHING;

-- morning-weather-push: her gün 03:00 UTC (06:00 İstanbul)
SELECT cron.schedule(
  'morning-weather-push-daily',
  '0 3 * * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/morning-weather-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', current_setting('app.webhook_secret', true)
      ),
      body := '{}'::jsonb
    );
  $$
) ON CONFLICT (jobname) DO NOTHING;

-- season-reminder-push: her gün 07:00 UTC (10:00 İstanbul)
SELECT cron.schedule(
  'season-reminder-push-daily',
  '0 7 * * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/season-reminder-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', current_setting('app.webhook_secret', true)
      ),
      body := '{}'::jsonb
    );
  $$
) ON CONFLICT (jobname) DO NOTHING;
