-- Gölge puan ve diğer Edge Function senaryoları için atomik skor artışı
CREATE OR REPLACE FUNCTION increment_user_score(p_user_id UUID, p_points INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE users
  SET total_score = total_score + p_points
  WHERE id = p_user_id;
END;
$$;

-- shadow_points: av paylaşımı kaynaklı gölge puan (posts.spot_id)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.shadow_points'::regclass
      AND conname = 'shadow_points_source_type_check'
  ) THEN
    ALTER TABLE shadow_points DROP CONSTRAINT shadow_points_source_type_check;
  END IF;
END $$;

ALTER TABLE shadow_points
  ADD CONSTRAINT shadow_points_source_type_check
  CHECK (source_type IN ('checkin', 'post'));
