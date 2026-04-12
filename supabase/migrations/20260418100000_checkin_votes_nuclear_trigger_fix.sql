-- ═══════════════════════════════════════════════════════════════════════════
-- Oylama: record "new" has no field "vote_type"
--
-- Kök neden: PL/pgSQL tetikleyici gövdesi NEW.vote_type okuyor; public.checkin_votes
-- satır tipinde bu alan yok (kolon adı "vote" BOOLEAN). Repo migration'ları doğru
-- fonksiyonu tanımlasa da aşağıdaki durumlarda hata sürer:
--   • Uzak projede migration hiç çalıştırılmadı / yanlış proje
--   • checkin_votes üzerinde ek, elle eklenmiş ikinci tetikleyici (vote_type kullanan)
--   • Eski fonksiyon + tetikleyici kısmen kaldırıldı
--
-- Bu dosya: tablodaki TÜM kullanıcı tetikleyicilerini düşürür, aggregate fonksiyonunu
-- CASCADE ile kaldırır, tek doğru sürümü ve tek tetikleyiciyi yeniden kurar.
--
-- Doğrulama (SQL Editor, migration sonrası):
--   SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'public.checkin_votes'::regclass AND NOT tgisinternal;
--   SELECT prosrc FROM pg_proc WHERE proname = 'apply_checkin_vote_aggregates';
--   İkincisinde "vote_type" geçmemeli; "vote = true" geçmeli.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tgname
    FROM pg_trigger
    WHERE tgrelid = 'public.checkin_votes'::regclass
      AND NOT tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.checkin_votes', r.tgname);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.apply_checkin_vote_aggregates() CASCADE;

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

CREATE TRIGGER trg_checkin_votes_aggregate
  AFTER INSERT OR UPDATE OR DELETE ON public.checkin_votes
  FOR EACH ROW
  EXECUTE PROCEDURE public.apply_checkin_vote_aggregates();
