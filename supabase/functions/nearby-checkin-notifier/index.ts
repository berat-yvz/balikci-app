import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Haversine formülü — iki koordinat arasındaki mesafeyi metre cinsinden döner.
function haversineMeters(
  lat1: number, lng1: number,
  lat2: number, lng2: number,
): number {
  const R = 6371000
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

serve(async (req) => {  
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { user_id, spot_id, lat, lng, spot_name } = await req.json()

    if (!user_id || !spot_id || lat == null || lng == null) {
      return new Response(
        JSON.stringify({ error: 'user_id, spot_id, lat, lng zorunlu' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── 1. Son 24 saatte check-in yapan kullanıcıların bulunduğu meraları bul ─
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    const { data: recentCheckins } = await supabase
      .from('checkins')
      .select('user_id, spot_id, spots!inner(lat, lng)')
      .neq('user_id', user_id)
      .gte('created_at', since)
      .limit(200)

    // 2km yarıçapındaki kullanıcıları filtrele
    const nearbyUserIds = new Set<string>()
    for (const c of recentCheckins ?? []) {
      const spot = (c as Record<string, unknown>).spots as { lat: number; lng: number } | null
      if (!spot) continue
      const dist = haversineMeters(lat, lng, spot.lat, spot.lng)
      if (dist <= 2000) {
        nearbyUserIds.add((c as Record<string, unknown>).user_id as string)
      }
    }

    // ── 2b. Favorileyenleri çıkar: onlara app tarafı zaten bildirdi ─────────
    const { data: favUsers } = await supabase
      .from('spot_favorites')
      .select('user_id')
      .eq('spot_id', spot_id)

    const favSet = new Set<string>(
      (favUsers ?? []).map((f: { user_id: string }) => f.user_id),
    )
    for (const id of favSet) nearbyUserIds.delete(id)
    nearbyUserIds.delete(user_id)

    if (nearbyUserIds.size === 0) {
      return new Response(
        JSON.stringify({ success: true, notified: 0 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── 3. Bildirim ayarları olan kullanıcıları filtrele ─────────────────────
    const { data: notifSettings } = await supabase
      .from('notification_settings')
      .select('user_id, checkin_nearby')
      .in('user_id', [...nearbyUserIds])

    const allowedIds = new Set<string>()
    for (const s of notifSettings ?? []) {
      const row = s as { user_id: string; checkin_nearby: boolean }
      if (row.checkin_nearby !== false) allowedIds.add(row.user_id)
    }
    // Ayarı olmayan kullanıcılar için varsayılan = izin verilmiş
    for (const id of nearbyUserIds) {
      if (!(notifSettings ?? []).some((s) => (s as { user_id: string }).user_id === id)) {
        allowedIds.add(id)
      }
    }

    // ── 4. Her kullanıcıya notification-sender çağır ─────────────────────────
    const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
    const authHeader = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
    const spotLabel = spot_name ?? 'Yakındaki mera'

    let notified = 0
    const sendPromises = [...allowedIds].map(async (uid) => {
      try {
        await fetch(senderUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: authHeader },
          body: JSON.stringify({
            user_id: uid,
            title: '🐟 Balık var!',
            body: `${spotLabel} yakınında check-in yapıldı.`,
            data: { type: 'checkin', spot_id },
          }),
        })
        notified++
      } catch (e) {
        console.error(`Bildirim gönderilemedi (${uid}):`, e)
      }
    })

    await Promise.allSettled(sendPromises)

    return new Response(
      JSON.stringify({ success: true, notified }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('nearby-checkin-notifier hata:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
