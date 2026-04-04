-- Storage trigger: fish-photos bucket'a fotoğraf yüklenince exif-verify Edge Function'ı tetikle
-- Bu trigger Supabase Dashboard > Database > Functions kısmında da görünür

CREATE OR REPLACE FUNCTION storage.trigger_exif_verify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  checkin_id uuid;
  file_path text;
BEGIN
  -- Yüklenen dosyanın path'inden check-in ID'sini çıkar
  -- Beklenen format: checkins/{checkin_id}/{filename}
  file_path := NEW.name;

  IF file_path LIKE 'checkins/%' THEN
    checkin_id := (string_to_array(file_path, '/'))[2]::uuid;

    -- Edge Function'ı HTTP ile çağır
    PERFORM net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/exif-verify',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body := jsonb_build_object(
        'checkinId', checkin_id,
        'storagePath', file_path,
        'bucket', NEW.bucket_id
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Trigger hatası ana işlemi engellemez
  RAISE WARNING 'exif-verify trigger hatası: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Trigger'ı storage.objects tablosuna bağla
DROP TRIGGER IF EXISTS on_storage_object_created ON storage.objects;
CREATE TRIGGER on_storage_object_created
  AFTER INSERT ON storage.objects
  FOR EACH ROW
  WHEN (NEW.bucket_id = 'fish-photos')
  EXECUTE FUNCTION storage.trigger_exif_verify();

-- app settings (supabase_url ve service_role_key Dashboard > Settings > API'den alınır)
-- Bu değerleri Supabase Dashboard > Database > Settings kısmında ALTER SYSTEM ile set et:
-- ALTER SYSTEM SET app.supabase_url = 'https://bcsihxgekoqwbovbmlog.supabase.co';
-- ALTER SYSTEM SET app.service_role_key = 'YOUR_SERVICE_ROLE_KEY';
-- SELECT pg_reload_conf();
