-- H6 oylama: checkin_votes RLS, sayaç kolonları, tetikleyici, checkins SELECT politikası
-- Idempotent. NOT: Geniş "UPDATE USING (true)" politikası güvenlik riski — gizleme tetikleyicide (SECURITY DEFINER).

-- ─── checkins: eksik kolonlar ───────────────────────────────────────────────
ALTER TABLE public.checkins
  ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.checkins
  ADD COLUMN IF NOT EXISTS true_votes INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.checkins
  ADD COLUMN IF NOT EXISTS false_votes INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.checkins
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

COMMENT ON COLUMN public.checkins.is_hidden IS 'Topluluk oylamasıyla gizlendi; SELECT politikasında filtrelenir.';
COMMENT ON COLUMN public.checkins.true_votes IS 'checkin_votes tetikleyicisi ile senkron';
COMMENT ON COLUMN public.checkins.false_votes IS 'checkin_votes tetikleyicisi ile senkron';

-- ─── Mevcut oylardan sayaçları doldur (tek seferlik) ─────────────────────────
UPDATE public.checkins c
SET
  true_votes = COALESCE(v.true_c, 0),
  false_votes = COALESCE(v.false_c, 0)
FROM (
  SELECT
    checkin_id,
    count(*) FILTER (WHERE vote = true) AS true_c,
    count(*) FILTER (WHERE vote = false) AS false_c
  FROM public.checkin_votes
  GROUP BY checkin_id
) v
WHERE c.id = v.checkin_id
  AND (c.true_votes IS DISTINCT FROM COALESCE(v.true_c, 0)
    OR c.false_votes IS DISTINCT FROM COALESCE(v.false_c, 0));

-- Eşik: AppConstants ile aynı (3 oy, %70 yanlış)
CREATE OR REPLACE FUNCTION public.apply_checkin_vote_aggregates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target uuid;
  tcount int;
  fcount int;
  total int;
BEGIN
  target := COALESCE(NEW.checkin_id, OLD.checkin_id);
  IF target IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT
    count(*) FILTER (WHERE vote = true),
    count(*) FILTER (WHERE vote = false)
  INTO tcount, fcount
  FROM public.checkin_votes
  WHERE checkin_id = target;

  total := tcount + fcount;

  UPDATE public.checkins
  SET
    true_votes = tcount,
    false_votes = fcount,
    is_hidden = CASE
      WHEN total >= 3
        AND total > 0
        AND (fcount::numeric / total::numeric) >= 0.70
      THEN true
      ELSE is_hidden
    END
  WHERE id = target;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_checkin_votes_aggregate ON public.checkin_votes;
CREATE TRIGGER trg_checkin_votes_aggregate
  AFTER INSERT OR UPDATE OR DELETE ON public.checkin_votes
  FOR EACH ROW
  EXECUTE PROCEDURE public.apply_checkin_vote_aggregates();

-- ─── checkin_votes RLS ──────────────────────────────────────────────────────
ALTER TABLE public.checkin_votes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkin_votes'
      AND policyname = 'Votes visible to all authenticated'
  ) THEN
    CREATE POLICY "Votes visible to all authenticated"
      ON public.checkin_votes FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkin_votes'
      AND policyname = 'Users can delete own vote'
  ) THEN
    CREATE POLICY "Users can delete own vote"
      ON public.checkin_votes FOR DELETE
      TO authenticated
      USING (voter_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkin_votes'
      AND policyname = 'Users can update own vote'
  ) THEN
    CREATE POLICY "Users can update own vote"
      ON public.checkin_votes FOR UPDATE
      TO authenticated
      USING (voter_id = auth.uid())
      WITH CHECK (voter_id = auth.uid());
  END IF;
END $$;

-- INSERT (mevcut isim çakışmazsa ekle)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkin_votes'
      AND policyname = 'Users can vote once per checkin'
  ) THEN
    CREATE POLICY "Users can vote once per checkin"
      ON public.checkin_votes FOR INSERT
      TO authenticated
      WITH CHECK (voter_id = auth.uid());
  END IF;
END $$;

-- ─── checkins SELECT: gizlileri gösterme ───────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'checkins'
      AND policyname = 'Active checkins visible to all'
  ) THEN
    DROP POLICY "Active checkins visible to all" ON public.checkins;
  END IF;

  CREATE POLICY "Active checkins visible to all"
    ON public.checkins FOR SELECT
    USING (
      COALESCE(is_active, true) = true
      AND COALESCE(is_hidden, false) = false
    );
END $$;

-- Gizlenmesi gereken mevcut kayıtlar
UPDATE public.checkins
SET is_hidden = true
WHERE COALESCE(is_hidden, false) = false
  AND (true_votes + false_votes) >= 3
  AND (true_votes + false_votes) > 0
  AND (false_votes::numeric / (true_votes + false_votes)::numeric) >= 0.70;

-- NOT: is_hidden güncellemesi tetikleyicide (SECURITY DEFINER). İstemci UPDATE yerine
-- tetikleyiciye güvenin. İleride score-calculator service_role ile sayaç/gizleme yapacaksa
-- bu fonksiyon korunur veya birleştirilir.
