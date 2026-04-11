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

const RANK_ORDER: Record<string, number> = {
  acemi: 0,
  olta_kurdu: 1,
  usta: 2,
  deniz_reisi: 3,
}

function rankFromScore(score: number): string {
  if (score >= 5000) return 'deniz_reisi'
  if (score >= 2000) return 'usta'
  if (score >= 500) return 'olta_kurdu'
  return 'acemi'
}

function rankLabelTr(rank: string): string {
  switch (rank) {
    case 'olta_kurdu':
      return 'Olta Kurdu'
    case 'usta':
      return 'Usta'
    case 'deniz_reisi':
      return 'Deniz Reisi'
    default:
      return 'Acemi'
  }
}

function sendRankUpNotification(
  userId: string,
  newRank: string,
  prevRank: string,
): void {
  const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
  const authHeader = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`

  void fetch(senderUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: authHeader },
    body: JSON.stringify({
      user_id: userId,
      title: '🏆 Tebrikler!',
      body: `Yeni rütben: ${rankLabelTr(newRank)}`,
      data: {
        type: 'rank_up',
        new_rank: newRank,
        prev_rank: prevRank,
      },
      force: true,
    }),
  }).catch((e) => console.error('rank_up notification-sender hatası:', e))
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

    const oldScore = Math.max(0, user.total_score ?? 0)
    const newScore = Math.max(0, oldScore + delta)

    const prevRank = rankFromScore(oldScore)
    const newRank = rankFromScore(newScore)

    await supabase
      .from('users')
      .update({ total_score: newScore, rank: newRank })
      .eq('id', user_id)

    const prevOrder = RANK_ORDER[prevRank] ?? 0
    const newOrder = RANK_ORDER[newRank] ?? 0
    if (newOrder > prevOrder) {
      sendRankUpNotification(user_id, newRank, prevRank)
    }

    return new Response(
      JSON.stringify({
        user_id,
        source_type,
        delta,
        newScore,
        newRank,
        rank_up_notified: newOrder > prevOrder,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
