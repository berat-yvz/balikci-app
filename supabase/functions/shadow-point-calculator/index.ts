import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SHADOW_POINTS = 20
const JSON_HDR = { 'Content-Type': 'application/json' }

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
  }).catch((e) => console.error('shadow-point rank_up notification-sender:', e))
}

function sendShadowPointPush(
  receiverUserId: string,
  posterUserId: string,
  posterUsername: string,
  spotName: string,
): void {
  const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
  const authHeader = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`

  void fetch(senderUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: authHeader },
    body: JSON.stringify({
      user_id: receiverUserId,
      actor_id: posterUserId,
      title: '📍 Gölge Puan Kazandın! +20',
      body:
        `${posterUsername} senin ${spotName} merana gidip av paylaştı!`,
      data: { type: 'shadow_point' },
      force: false,
    }),
  }).catch((e) => console.error('shadow-point notification-sender:', e))
}

type ShadowBody = {
  post_id?: unknown
  poster_user_id?: unknown
  spot_id?: unknown
}

serve(async (req: Request) => {
  try {
    const authorizationHeader = req.headers.get('Authorization')
    if (!authorizationHeader?.startsWith('Bearer ')) {
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

    let authUserId: string
    try {
      const { data: authData, error: authErr } = await supabase.auth.getUser(token)
      if (authErr || !authData.user) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: JSON_HDR,
        })
      }
      authUserId = authData.user.id
    } catch (e) {
      console.error('shadow-point-calculator auth.getUser:', e)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    let body: ShadowBody
    try {
      body = await req.json() as ShadowBody
    } catch {
      return new Response(JSON.stringify({ error: 'invalid_json' }), {
        status: 400,
        headers: JSON_HDR,
      })
    }

    const postId = typeof body.post_id === 'string' ? body.post_id : undefined
    const posterUserId =
      typeof body.poster_user_id === 'string' ? body.poster_user_id : undefined

    const spotRaw = body.spot_id
    const spotId =
      typeof spotRaw === 'string' && spotRaw.trim().length > 0
        ? spotRaw.trim()
        : undefined

    if (!postId || !posterUserId) {
      return new Response(JSON.stringify({ error: 'missing_required_fields' }), {
        status: 400,
        headers: JSON_HDR,
      })
    }

    if (posterUserId !== authUserId) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: JSON_HDR,
      })
    }

    if (!spotId) {
      return new Response(
        JSON.stringify({ message: 'spot_yok_golgepuan_verilmedi' }),
        { status: 200, headers: JSON_HDR },
      )
    }

    const { data: spot, error: spotErr } = await supabase
      .from('fishing_spots')
      .select('user_id, name, privacy_level')
      .eq('id', spotId)
      .maybeSingle()

    if (spotErr) {
      console.error('shadow-point-calculator spot sorgu:', spotErr)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    if (!spot?.user_id) {
      return new Response(JSON.stringify({ message: 'spot_bulunamadi' }), {
        status: 200,
        headers: JSON_HDR,
      })
    }

    const spotOwnerId = spot.user_id as string

    if (spotOwnerId === posterUserId) {
      return new Response(JSON.stringify({ message: 'oz_mera_golge_yok' }), {
        status: 200,
        headers: JSON_HDR,
      })
    }

    const { count: existingCount, error: cntErr } = await supabase
      .from('shadow_points')
      .select('id', { count: 'exact', head: true })
      .eq('source_id', postId)
      .eq('receiver_id', spotOwnerId)

    if (cntErr) {
      console.error('shadow-point-calculator mükerrer sayım:', cntErr)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    if (existingCount != null && existingCount > 0) {
      return new Response(JSON.stringify({ message: 'zaten_verilmis' }), {
        status: 200,
        headers: JSON_HDR,
      })
    }

    const { error: insErr } = await supabase.from('shadow_points').insert({
      source_id: postId,
      source_type: 'post',
      giver_id: posterUserId,
      receiver_id: spotOwnerId,
      points: SHADOW_POINTS,
    })

    if (insErr) {
      console.error('shadow_points insert:', insErr)
      if (insErr.code === '23505') {
        return new Response(JSON.stringify({ message: 'zaten_verilmis' }), {
          status: 200,
          headers: JSON_HDR,
        })
      }
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    const { data: receiverBefore, error: recvErr } = await supabase
      .from('users')
      .select('total_score')
      .eq('id', spotOwnerId)
      .single()

    if (recvErr || !receiverBefore) {
      console.error('shadow-point-calculator receiver okuma:', recvErr)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    const oldScore = Math.max(0, receiverBefore.total_score ?? 0)
    const prevRank = rankFromScore(oldScore)
    const newScore = oldScore + SHADOW_POINTS
    const newRank = rankFromScore(newScore)

    const { error: rpcErr } = await supabase.rpc('increment_user_score', {
      p_user_id: spotOwnerId,
      p_points: SHADOW_POINTS,
    })

    if (rpcErr) {
      console.error('increment_user_score:', rpcErr)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    const { error: rankErr } = await supabase
      .from('users')
      .update({ rank: newRank })
      .eq('id', spotOwnerId)

    if (rankErr) {
      console.error('shadow-point-calculator rank güncelleme:', rankErr)
      return new Response(JSON.stringify({ error: 'internal_error' }), {
        status: 500,
        headers: JSON_HDR,
      })
    }

    const prevOrder = RANK_ORDER[prevRank] ?? 0
    const newOrder = RANK_ORDER[newRank] ?? 0
    if (newOrder > prevOrder) {
      sendRankUpNotification(spotOwnerId, newRank, prevRank)
    }

    const { data: poster } = await supabase
      .from('users')
      .select('username')
      .eq('id', posterUserId)
      .maybeSingle()

    const posterUsername =
      (poster?.username as string | undefined)?.trim() || 'Bir balıkçı'
    const spotName = ((spot.name as string | undefined)?.trim() || 'bir')

    sendShadowPointPush(spotOwnerId, posterUserId, posterUsername, spotName)

    return new Response(
      JSON.stringify({
        message: 'golge_puan_verildi',
        receiver: spotOwnerId,
        points: SHADOW_POINTS,
      }),
      { status: 200, headers: JSON_HDR },
    )
  } catch (err) {
    console.error('shadow-point-calculator:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: JSON_HDR },
    )
  }
})
