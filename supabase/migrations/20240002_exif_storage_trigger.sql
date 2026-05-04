-- pg_net extension'ı etkinleştir (Supabase'de varsayılan açık olmalı)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Edge Function URL'i ve anahtarı direkt gömüyoruz
-- (Bu migration sadece Supabase Dashboard SQL Editor'dan çalışır, kaynak kodda service_role_key olmaz)
CREATE OR REPLACE FUNCTION storage.trigger_exif_verify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  checkin_id text;
  parts text[];
BEGIN
  -- Beklenen path formatı: checkins/{checkin_id}/{filename}
  IF NEW.bucket_id = 'fish-photos' AND NEW.name LIKE 'checkins/%' THEN
    parts := string_to_array(NEW.name, '/');
    IF array_length(parts, 1) >= 2 THEN
      checkin_id := parts[2];

      PERFORM net.http_post(
        url     := 'https://bcsihxgekoqwbovbmlog.supabase.co/functions/v1/exif-verify',
        headers := jsonb_build_object(
          'Content-Type',  'application/json'
          -- GÜVENLİK NOTU: Service role key buraya YAZILMAZ.
          -- Bu trigger artık check-in akışında kullanılmıyor (ARCHITECTURE.md).
          -- Eğer yeniden aktif edilecekse key Supabase Vault veya
          -- Dashboard > Edge Functions > Secrets üzerinden inject edilmeli.
        ),
        body    := jsonb_build_object(
          'checkinId',   checkin_id,
          'storagePath', NEW.name,
          'bucket',      NEW.bucket_id
        )::text
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'exif-verify trigger hatası: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_fish_photo_uploaded ON storage.objects;
CREATE TRIGGER on_fish_photo_uploaded
  AFTER INSERT ON storage.objects
  FOR EACH ROW
  EXECUTE FUNCTION storage.trigger_exif_verify();
