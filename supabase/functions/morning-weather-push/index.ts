import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Kullanıcılara sabah 06:00'da hava durumu push bildirimi gönderir ─────────
// Bu fonksiyon pg_cron ile 03:00 UTC'de (06:00 İstanbul) tetiklenir.
// Son 30 günde aktif olan kullanıcılara 1 bildirim gönderilir.
// Her kullanıcı için weather_cache tablosundan güncel özet alınır.

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // ── Son 30 günde aktif kullanıcılar (bildirim izni verilmiş) ─────────────
    const since30d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const { data: activeUsers } = await supabase
      .from('checkins')
      .select('user_id')
      .gte('created_at', since30d)
      .limit(1000)

    const uniqueUserIds = [...new Set(
      (activeUsers ?? []).map((r: { user_id: string }) => r.user_id),
    )]

    if (uniqueUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: 'no_active_users' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── Bildirim ayarlarını filtrele ─────────────────────────────────────────
    const { data: notifSettings } = await supabase
      .from('notification_settings')
      .select('user_id, weather_morning')
      .in('user_id', uniqueUserIds)

    const disabledSet = new Set<string>(
      (notifSettings ?? [])
        .filter((s: { user_id: string; weather_morning: boolean }) => s.weather_morning === false)
        .map((s: { user_id: string }) => s.user_id),
    )
    const eligibleUserIds = uniqueUserIds.filter((id) => !disabledSet.has(id))

    if (eligibleUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: 'all_disabled' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── İstanbul hava özetini al (weather_cache: region_key + open_meteo_v1) ─
    const { data: weatherRow } = await supabase
      .from('weather_cache')
      .select('fishing_summary, data_json')
      .eq('region_key', 'istanbul')
      .maybeSingle()

    const summary = weatherRow?.fishing_summary ?? 'Bugün hava durumunu kontrol et 🎣'
    let wind = ''
    let temp = ''
    const dj = weatherRow?.data_json as Record<string, unknown> | null | undefined
    const cur = dj?.current as Record<string, unknown> | undefined
    if (cur) {
      const w = cur.windspeed as number | undefined
      const t = cur.temperature as number | undefined
      if (w != null) wind = `💨 ${Math.round(w)} km/s`
      if (t != null) temp = `🌡️ ${Math.round(t)}°C`
    }
    const detail = [temp, wind].filter(Boolean).join('  ')

    const notifBody = detail ? `${summary}\n${detail}` : summary

    // ── Her kullanıcıya bildirim gönder (force=true: sabah bildirimi limit dışı) ─
    const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
    const authHeader = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`

    let sent = 0
    // Toplu istek: 50'şerli batch
    const batchSize = 50
    for (let i = 0; i < eligibleUserIds.length; i += batchSize) {
      const batch = eligibleUserIds.slice(i, i + batchSize)
      await Promise.allSettled(
        batch.map(async (uid) => {
          try {
            await fetch(senderUrl, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', Authorization: authHeader },
              body: JSON.stringify({
                user_id: uid,
                title: '☀️ Günaydın Balıkçı!',
                body: notifBody,
                data: { type: 'weather_morning' },
                force: true, // günlük limit sayılmaz
              }),
            })
            sent++
          } catch (e) {
            console.error(`Sabah bildirimi gönderilemedi (${uid}):`, e)
          }
        }),
      )
    }

    return new Response(
      JSON.stringify({ success: true, sent, total: eligibleUserIds.length }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('morning-weather-push hata:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
