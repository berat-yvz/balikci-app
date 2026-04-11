-- Sıra sayfası: RLS yüzünden boş dönen listeler için güvenli okuma (SECURITY DEFINER).
-- Sosyal: arkadaşlık isteği tablosu.

-- ─── 1) Liderlik — yalnızca güvenli kolonlar ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.leaderboard_users(limit_count int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  username text,
  avatar_url text,
  rank text,
  total_score int,
  sustainability_score int,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.avatar_url,
    u.rank,
    COALESCE(u.total_score, 0)::int,
    COALESCE(u.sustainability_score, 0)::int,
    u.created_at
  FROM public.users u
  ORDER BY u.total_score DESC NULLS LAST, u.created_at ASC
  LIMIT GREATEST(1, LEAST(COALESCE(limit_count, 100), 500));
$$;

REVOKE ALL ON FUNCTION public.leaderboard_users(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.leaderboard_users(int) TO authenticated;

-- ─── 2) Tüm kayıtlı balıkçılar (sosyal keşif) ────────────────────────────────
CREATE OR REPLACE FUNCTION public.all_registered_anglers(limit_count int DEFAULT 2000)
RETURNS TABLE (
  id uuid,
  username text,
  avatar_url text,
  rank text,
  total_score int,
  sustainability_score int,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.avatar_url,
    u.rank,
    COALESCE(u.total_score, 0)::int,
    COALESCE(u.sustainability_score, 0)::int,
    u.created_at
  FROM public.users u
  ORDER BY LOWER(u.username) ASC NULLS LAST, u.created_at ASC
  LIMIT GREATEST(1, LEAST(COALESCE(limit_count, 2000), 5000));
$$;

REVOKE ALL ON FUNCTION public.all_registered_anglers(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.all_registered_anglers(int) TO authenticated;

-- ─── 3) Haftalık sıra (checkins + users; RLS baypas) ─────────────────────────
CREATE OR REPLACE FUNCTION public.weekly_leaderboard(limit_count int DEFAULT 50)
RETURNS TABLE (
  user_id uuid,
  username text,
  avatar_url text,
  rank text,
  checkin_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    c.user_id,
    u.username,
    u.avatar_url,
    u.rank,
    COUNT(*)::bigint AS checkin_count
  FROM public.checkins c
  INNER JOIN public.users u ON u.id = c.user_id
  WHERE c.created_at >= (timezone('utc', now()) - interval '7 days')
    AND COALESCE(c.is_hidden, false) = false
  GROUP BY c.user_id, u.username, u.avatar_url, u.rank
  ORDER BY checkin_count DESC
  LIMIT GREATEST(1, LEAST(COALESCE(limit_count, 50), 200));
$$;

REVOKE ALL ON FUNCTION public.weekly_leaderboard(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.weekly_leaderboard(int) TO authenticated;

-- ─── 4) Arkadaşlık istekleri ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (from_user_id, to_user_id),
  CHECK (from_user_id <> to_user_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_to_status
  ON public.friend_requests (to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_from_status
  ON public.friend_requests (from_user_id, status);

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friend_requests_select_own" ON public.friend_requests;
CREATE POLICY "friend_requests_select_own"
  ON public.friend_requests FOR SELECT
  TO authenticated
  USING (from_user_id = auth.uid() OR to_user_id = auth.uid());

DROP POLICY IF EXISTS "friend_requests_insert_outgoing" ON public.friend_requests;
CREATE POLICY "friend_requests_insert_outgoing"
  ON public.friend_requests FOR INSERT
  TO authenticated
  WITH CHECK (from_user_id = auth.uid());

DROP POLICY IF EXISTS "friend_requests_update_recipient" ON public.friend_requests;
CREATE POLICY "friend_requests_update_recipient"
  ON public.friend_requests FOR UPDATE
  TO authenticated
  USING (to_user_id = auth.uid())
  WITH CHECK (to_user_id = auth.uid());

-- İsteği gönderen iptal edebilsin (sadece pending)
DROP POLICY IF EXISTS "friend_requests_delete_sender_pending" ON public.friend_requests;
CREATE POLICY "friend_requests_delete_sender_pending"
  ON public.friend_requests FOR DELETE
  TO authenticated
  USING (from_user_id = auth.uid() AND status = 'pending');

-- İstek kabulü: karşılıklı takip (RLS tek yönde INSERT’i aşmak için)
CREATE OR REPLACE FUNCTION public.accept_friend_request(request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  from_u uuid;
  to_u uuid;
BEGIN
  SELECT fr.from_user_id, fr.to_user_id
  INTO from_u, to_u
  FROM public.friend_requests fr
  WHERE fr.id = request_id
    AND fr.status = 'pending'
    AND fr.to_user_id = auth.uid();

  IF from_u IS NULL THEN
    RAISE EXCEPTION 'Geçersiz veya süresi dolmuş istek';
  END IF;

  UPDATE public.friend_requests
  SET status = 'accepted'
  WHERE id = request_id;

  INSERT INTO public.follows (follower_id, following_id)
  VALUES (from_u, to_u)
  ON CONFLICT (follower_id, following_id) DO NOTHING;

  INSERT INTO public.follows (follower_id, following_id)
  VALUES (to_u, from_u)
  ON CONFLICT (follower_id, following_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_friend_request(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_friend_request(uuid) TO authenticated;

-- ─── 5) users okuma — eski projelerde eksikse (idempotent) ───────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'users'
      AND policyname = 'users_select_authenticated'
  ) THEN
    CREATE POLICY "users_select_authenticated"
      ON public.users FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;
