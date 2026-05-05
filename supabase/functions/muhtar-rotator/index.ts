import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

  // Webhook secret koruması
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

    // 1. Tüm public meraları çek
    const { data: spots, error: spotsError } = await supabase
      .from('fishing_spots')
      .select('id, user_id, muhtar_id')
      .eq('privacy_level', 'public')

    if (spotsError) throw spotsError
    if (!spots || spots.length === 0) {
      return new Response(
        JSON.stringify({ success: true, updated: 0 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    let updatedCount = 0
    const errors: string[] = []

    for (const spot of spots) {
      try {
        // 2. Bu meradaki son 30 günlük check-in istatistiklerini hesapla
        const since30d = new Date()
        since30d.setDate(since30d.getDate() - 30)

        const { data: checkins, error: checkinError } = await supabase
          .from('checkins')
          .select('id, user_id')
          .eq('spot_id', spot.id)
          .gte('created_at', since30d.toISOString())
          .eq('is_active', true)

        if (checkinError || !checkins || checkins.length === 0) continue

        // 3. Her kullanıcı için oy istatistiklerini hesapla
        const userStats: Record<
          string,
          { trueVotes: number; totalVotes: number; checkinCount: number }
        > = {}

        for (const checkin of checkins) {
          const uid: string = checkin.user_id
          if (!userStats[uid]) {
            userStats[uid] = { trueVotes: 0, totalVotes: 0, checkinCount: 0 }
          }
          userStats[uid].checkinCount += 1

          // Bu check-in'e ait oyları çek
          const { data: votes } = await supabase
            .from('checkin_votes')
            .select('vote')
            .eq('checkin_id', checkin.id)

          if (votes) {
            for (const v of votes) {
              userStats[uid].totalVotes += 1
              if (v.vote === true) userStats[uid].trueVotes += 1
            }
          }
        }

        // 4. Muhtar adayı kriterleri:
        // - En az 5 check-in
        // - true_votes / total_votes >= 0.80 (doğruluk oranı)
        // - En yüksek true_votes sayısı
        let bestUserId: string | null = null
        let bestTrueVotes = -1

        for (const [uid, stats] of Object.entries(userStats)) {
          if (stats.checkinCount < 5) continue
          if (stats.totalVotes === 0) continue
          const ratio = stats.trueVotes / stats.totalVotes
          if (ratio < 0.80) continue
          if (stats.trueVotes > bestTrueVotes) {
            bestTrueVotes = stats.trueVotes
            bestUserId = uid
          }
        }

        // 5. Muhtar değişti mi kontrol et
        if (bestUserId === spot.muhtar_id) continue

        // 6. fishing_spots.muhtar_id güncelle
        const { error: updateError } = await supabase
          .from('fishing_spots')
          .update({ muhtar_id: bestUserId })
          .eq('id', spot.id)

        if (updateError) {
          errors.push(`Spot ${spot.id}: ${updateError.message}`)
          continue
        }

        updatedCount += 1

        // 7. Yeni muhtar varsa bildirim gönder
        if (bestUserId) {
          const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
          const senderAuth = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
          await fetch(senderUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: senderAuth },
            body: JSON.stringify({
              user_id: bestUserId,
              title: '👑 Tebrikler, Muhtar Oldun!',
              body: 'Bu meranın en güvenilir balıkçısısın. Muhtar unvanı senindir!',
              data: { type: 'muhtar', spot_id: spot.id },
            }),
          }).catch((e) => console.error('notification-sender hatası:', e))
        }
      } catch (spotErr) {
        errors.push(`Spot ${spot.id}: ${String(spotErr)}`)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        updated: updatedCount,
        total_spots: spots.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('muhtar-rotator hatası:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
