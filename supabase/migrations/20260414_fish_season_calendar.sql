-- Balık sezon hatırlatması: yıllık açılış tarihleri + gönderim günlüğü (H10).
-- Edge Function: season-reminder-push — pg_cron ile günlük tetiklenir (bkz. supabase/cron_season_reminder_push.sql).

CREATE TABLE IF NOT EXISTS public.fish_season_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  species_name text NOT NULL,
  start_month smallint NOT NULL CHECK (start_month BETWEEN 1 AND 12),
  start_day smallint NOT NULL CHECK (start_day BETWEEN 1 AND 31),
  notify_days_before smallint NOT NULL DEFAULT 7 CHECK (notify_days_before BETWEEN 1 AND 90),
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.fish_season_calendar IS
  'Yıllık tekrarlayan av sezonu açılış hatırlatmaları; tarihler örnek olabilir, yönetim panelinden güncellenmeli.';

CREATE TABLE IF NOT EXISTS public.fish_season_push_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  calendar_id uuid NOT NULL REFERENCES public.fish_season_calendar(id) ON DELETE CASCADE,
  season_year smallint NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, calendar_id, season_year)
);

CREATE INDEX IF NOT EXISTS idx_fish_season_push_log_sent
  ON public.fish_season_push_log (calendar_id, season_year);

ALTER TABLE public.fish_season_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fish_season_push_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fish_season_calendar_select_authenticated" ON public.fish_season_calendar;
CREATE POLICY "fish_season_calendar_select_authenticated"
  ON public.fish_season_calendar FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Push günlüğü yalnızca service role (Edge) tarafından kullanılır; istemci erişimi yok.

-- Bildirim tercihi: mevcut projede tablo yoksa atlanır (Edge yine varsayılan=açık davranır).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notification_settings'
  ) THEN
    ALTER TABLE public.notification_settings
      ADD COLUMN IF NOT EXISTS season_reminder boolean DEFAULT true;
  END IF;
END $$;

-- Örnek kayıtlar (sabit id ile tekrar çalıştırmada çakışma olmaz). Gerçek av düzenlemelerine göre güncelleyin.
INSERT INTO public.fish_season_calendar (id, species_name, start_month, start_day, notify_days_before, notes)
VALUES
  (
    'b1e00001-0000-4000-8000-000000000001'::uuid,
    'Lüfer',
    4,
    15,
    7,
    'Örnek açılış; bölge ve yıla göre resmi takvimi doğrulayın.'
  ),
  (
    'b1e00001-0000-4000-8000-000000000002'::uuid,
    'Palamut',
    9,
    1,
    7,
    'Örnek sonbahar sezonu hatırlatması.'
  ),
  (
    'b1e00001-0000-4000-8000-000000000003'::uuid,
    'Çipura (örnek)',
    5,
    1,
    7,
    'Örnek; kıyı/bölge kuralları farklı olabilir.'
  )
ON CONFLICT (id) DO NOTHING;
