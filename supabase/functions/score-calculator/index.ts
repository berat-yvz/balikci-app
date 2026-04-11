import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const POINTS: Record<string, number> = {
  checkin_verified: 30,
  checkin_unverified: 15,
  correct_vote: 10,
  wrong_report: -20,
  fish_log_public: 10,
  release_exif: 40,
  spot_public: 50,
}

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { source_type, user_id } = await req.json()
    const delta = POINTS[source_type] ?? 0

    if (delta === 0) {
      return new Response(
        JSON.stringify({ message: 'no-op', source_type }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const { data: user, error } = await supabase
      .from('users')
      .select('total_score')
      .eq('id', user_id)
      .single()

    if (error || !user) {
      return new Response(
        JSON.stringify({ error: 'User not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const newScore = Math.max(0, (user.total_score ?? 0) + delta)

    const newRank =
      newScore >= 5000 ? 'deniz_reisi'
      : newScore >= 2000 ? 'usta'
      : newScore >= 500  ? 'olta_kurdu'
      : 'acemi'

    await supabase
      .from('users')
      .update({ total_score: newScore, rank: newRank })
      .eq('id', user_id)

    return new Response(
      JSON.stringify({ user_id, source_type, delta, newScore, newRank }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})