-- Oturumdaki kullanıcının genel sıra numarası (1 tabanlı). RLS baypas.
CREATE OR REPLACE FUNCTION public.my_leaderboard_rank(check_user_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    1 + (
      SELECT COUNT(*)::int
      FROM public.users u
      WHERE COALESCE(u.total_score, 0) > COALESCE(
        (SELECT u2.total_score FROM public.users u2 WHERE u2.id = check_user_id),
        0
      )
    );
$$;

REVOKE ALL ON FUNCTION public.my_leaderboard_rank(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_leaderboard_rank(uuid) TO authenticated;
