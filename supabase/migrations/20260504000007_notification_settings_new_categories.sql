-- notification_settings tablosuna eksik bildirim kategorilerini ekle

ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS checkin_spot_owner BOOLEAN DEFAULT true;

ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS checkin_favorite BOOLEAN DEFAULT true;

ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS vote_received BOOLEAN DEFAULT true;

ALTER TABLE public.notification_settings
  ADD COLUMN IF NOT EXISTS rank_up BOOLEAN DEFAULT true;
