import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const POINTS: Record<string, number> = {
  checkin_unverified: 15,
  correct_vote: 10,
  wrong_report: -20,
  spot_public: 50,
  spot_friends: 30,
  spot_private: 10,
  post_share: 20,
  post_liked: 5,
  post_comment: 2,
}

const RANK_ORDER: Record<string, number> = {
  acemi: 0,
  olta_kurdu: 1,
  usta: 2,
  deniz_reisi: 3,
}

const JSON_HDR = { 'Content-Type': 'application/json' }

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

function rankBodyTr(rank: string): string {
  switch (rank) {
    case 'olta_kurdu':
      return 'Tebrikler Reis! Artık OLTA KURDUSU\'sun! 🎣\nArkadaşlarının gizli meralarını artık görebilirsin.'
    case 'usta':
      return 'Bravo! USTA BALIKÇI oldun! ⚓\nVIP meralar artık senin için açık.'
    case 'deniz_reisi':
      return 'Efsane! DENİZ REİSİ oldun! 🌊\nUygulamanın en seçkin balıkçısısın.'
    default:
      return `Yeni rütben: ${rankLabelTr(rank)}`
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
      body: rankBodyTr(newRank),
      data: {
        type: 'rank_up',
        new_rank: newRank,
        prev_rank: prevRank,
      },
      force: true,
    }),
  }).catch((e) => console.error('rank_up notification-sender hatası:', e))
}

type ScoreBody = {
  source_type?: unknown
  user_id?: unknown
  source_id?: unknown
  spot_id?: unknown
  post_id?: unknown
  liker_id?: unknown
}

serve(async (req: Request) => {
  try {
    const authorizationHeader = req.headers.get('Authorization')
    if (!authorizationHeader || !authorizationHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: JSON_HDR,
      })
    }
    const token = authorizationHeader.slice('Bearer '.length)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    try {
      const { data: authData, error: authErr } = await supabase.auth.getUser(token)
      if (authErr || !authData.user) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: JSON_HDR,
        })
      }
    } catch (e) {
      console.error('score-calculator auth.getUser:', e)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    let body: ScoreBody
    try {
      body = await req.json() as ScoreBody
    } catch {
      return new Response(JSON.stringify({ error: 'invalid_json' }), {
        status: 400,
        headers: JSON_HDR,
      })
    }

    const source_type = body.source_type
    const user_id = body.user_id
    // source_id gövdede kabul edilir (ileride gölge puan); şimdilik kullanılmıyor.
    const spot_id = typeof body.spot_id === 'string' ? body.spot_id : undefined
    const post_id = typeof body.post_id === 'string' ? body.post_id : undefined
    const liker_id = typeof body.liker_id === 'string' ? body.liker_id : undefined

    if (typeof source_type !== 'string' || !(source_type in POINTS)) {
      console.warn('Bilinmeyen source_type: ' + String(source_type))
      return new Response(JSON.stringify({ error: 'unknown_source_type' }), {
        status: 400,
        headers: JSON_HDR,
      })
    }

    if (typeof user_id !== 'string') {
      return new Response(JSON.stringify({ error: 'invalid_user_id' }), {
        status: 400,
        headers: JSON_HDR,
      })
    }

    const delta = POINTS[source_type]

    if (source_type === 'checkin_unverified' && spot_id !== undefined) {
      try {
        const today = new Date().toLocaleDateString('sv', { timeZone: 'Europe/Istanbul' })
        const dayStart = `${today}T00:00:00+03:00`
        const dayEnd = `${today}T23:59:59.999+03:00`
        const { count, error: cntErr } = await supabase
          .from('checkins')
          .select('id', { count: 'exact', head: true })
          .eq('user_id', user_id)
          .eq('spot_id', spot_id)
          .gte('created_at', dayStart)
          .lte('created_at', dayEnd)

        if (cntErr) throw cntErr
        if (count != null && count > 1) {
          return new Response(
            JSON.stringify({ message: 'gunluk_limit', awarded: 0 }),
            { status: 200, headers: JSON_HDR },
          )
        }
      } catch (e) {
        console.error('score-calculator checkin günlük limit:', e)
        return new Response(JSON.stringify({ error: 'internal_error' }), {
          status: 500,
          headers: JSON_HDR,
        })
      }
    }

    if (source_type === 'post_liked' && post_id !== undefined) {
      try {
        const { data: post, error: postErr } = await supabase
          .from('posts')
          .select('likes_count, user_id')
          .eq('id', post_id)
          .maybeSingle()

        if (postErr) throw postErr
        if (!post) {
          return new Response(
            JSON.stringify({ message: 'post_not_found', awarded: 0 }),
            { status: 200, headers: JSON_HDR },
          )
        }

        const ownerId = post.user_id as string
        if (ownerId !== user_id) {
          return new Response(JSON.stringify({ error: 'user_mismatch' }), {
            status: 400,
            headers: JSON_HDR,
          })
        }

        if (liker_id !== undefined && liker_id === ownerId) {
          return new Response(
            JSON.stringify({ message: 'oz_begeni', awarded: 0 }),
            { status: 200, headers: JSON_HDR },
          )
        }

        const likesCount = (post.likes_count as number | null | undefined) ?? 0
        if (likesCount % 10 !== 0) {
          return new Response(
            JSON.stringify({ message: 'limit_degil', awarded: 0 }),
            { status: 200, headers: JSON_HDR },
          )
        }
      } catch (e) {
        console.error('score-calculator post_liked doğrulama:', e)
        return new Response(JSON.stringify({ error: 'internal_error' }), {
          status: 500,
          headers: JSON_HDR,
        })
      }
    }

    let oldScore = 0
    let newScore = 0
    let prevRank = 'acemi'
    let newRank = 'acemi'

    try {
      const { data: user, error: userErr } = await supabase
        .from('users')
        .select('total_score')
        .eq('id', user_id)
        .single()

      if (userErr || !user) {
        return new Response(
          JSON.stringify({ error: 'User not found' }),
          { status: 404, headers: JSON_HDR },
        )
      }

      oldScore = Math.max(0, user.total_score ?? 0)
      newScore = Math.max(0, oldScore + delta)

      prevRank = rankFromScore(oldScore)
      newRank = rankFromScore(newScore)

      const { error: updErr } = await supabase
        .from('users')
        .update({ total_score: newScore, rank: newRank })
        .eq('id', user_id)

      if (updErr) throw updErr
    } catch (e) {
      console.error('score-calculator users güncelleme:', e)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

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
        awarded: delta,
      }),
      { status: 200, headers: JSON_HDR },
    )
  } catch (err) {
    console.error('score-calculator:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: JSON_HDR },
    )
  }
})
