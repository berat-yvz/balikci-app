import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SHADOW_POINT_VALUE = 20

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type, x-webhook-secret',
      },
    })
  }

  // Webhook secret koruması (diğer fonksiyonlarla tutarlı)
  const webhookSecret = Deno.env.get('WEBHOOK_SECRET')
  if (webhookSecret) {
    const secretHeader = req.headers.get('x-webhook-secret')
    if (secretHeader !== webhookSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const reqBody = await req.json()
    const fishLogId: string = reqBody.fish_log_id
    const giverId: string = reqBody.user_id

    if (!fishLogId || !giverId) {
      return new Response(
        JSON.stringify({ error: 'fish_log_id ve user_id zorunlu' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 1. fish_logs kaydından spot_id'yi al
    const { data: fishLog, error: logError } = await supabase
      .from('fish_logs')
      .select('spot_id')
      .eq('id', fishLogId)
      .maybeSingle()

    if (logError || !fishLog) {
      return new Response(
        JSON.stringify({ error: 'fish_log bulunamadı' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    if (!fishLog.spot_id) {
      return new Response(
        JSON.stringify({ success: false, reason: 'spot_id yok' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 2. Meranın sahibini bul
    const { data: spot, error: spotError } = await supabase
      .from('fishing_spots')
      .select('user_id')
      .eq('id', fishLog.spot_id)
      .maybeSingle()

    if (spotError || !spot) {
      return new Response(
        JSON.stringify({ error: 'Mera bulunamadı' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const receiverId: string = spot.user_id

    // 3. Kendi kendine puan yasak (DB CHECK constraint da var ama önce kontrol et)
    if (giverId === receiverId) {
      return new Response(
        JSON.stringify({ success: false, reason: 'self_award_prevented' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 4. shadow_points INSERT — UNIQUE(source_id, receiver_id) tekrar puanı engeller
    const { error: insertError } = await supabase
      .from('shadow_points')
      .insert({
        giver_id: giverId,
        receiver_id: receiverId,
        source_id: fishLogId,
        source_type: 'fish_log',
        points: SHADOW_POINT_VALUE,
      })

    if (insertError?.code === '23505') {
      return new Response(
        JSON.stringify({ success: false, reason: 'already_awarded' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    if (insertError) throw insertError

    // 5. Mera sahibinin puanını güncelle (score-calculator pattern: oku → hesapla → yaz)
    const { data: rcvUser } = await supabase
      .from('users')
      .select('total_score')
      .eq('id', receiverId)
      .single()

    const newScore = Math.max(0, (rcvUser?.total_score ?? 0) + SHADOW_POINT_VALUE)

    await supabase
      .from('users')
      .update({ total_score: newScore })
      .eq('id', receiverId)

    // 6. Mera sahibine bildirim gönder (fire-and-forget)
    const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
    const senderAuth = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
    void fetch(senderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: senderAuth },
      body: JSON.stringify({
        user_id: receiverId,
        title: '📍 Gölge Puan Kazandın!',
        body: `Paylaştığın merada bir balıkçı av yaptı. +${SHADOW_POINT_VALUE} puan!`,
        data: { type: 'shadow_point', spot_id: fishLog.spot_id },
      }),
    }).catch((e) => console.error('notification-sender hatası:', e))

    return new Response(
      JSON.stringify({ success: true, receiver_id: receiverId, points: SHADOW_POINT_VALUE }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('shadow-point-calculator hatası:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
