-- Muhtar rotasyonu: her ayın 1'i saat 02:00 UTC'de çalışır
SELECT cron.schedule(
  'muhtar-rotator-monthly',
  '0 2 1 * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/muhtar-rotator',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', current_setting('app.webhook_secret', true)
      ),
      body := '{}'::jsonb
    );
  $$
) ON CONFLICT (jobname) DO NOTHING;
