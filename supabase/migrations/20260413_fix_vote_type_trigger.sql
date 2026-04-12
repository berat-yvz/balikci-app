-- ═══════════════════════════════════════════════════════════════════════════
-- Supabase Dashboard → SQL Editor’de de çalıştırılabilir (migration zaten
-- uygulanmış projelerde eski tetikleyiciyi düzeltmek için).
--
-- Sorun: Bazı veritabanlarında checkin_votes tetikleyicisi NEW.vote_type
-- kullanıyor; tabloda kolon adı "vote" (BOOLEAN). Bu dosya fonksiyonu
-- yalnızca "vote" ile yeniden tanımlar.
-- ═══════════════════════════════════════════════════════════════════════════

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
