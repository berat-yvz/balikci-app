import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── İstanbul takvimi (UTC+3, DST yok) — gün farkı hesabı ─────────────────────

function istanbulYmd(d: Date): string {
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d)
}

function noonIstanbulMs(ymd: string): number {
  return new Date(`${ymd}T12:00:00+03:00`).getTime()
}

/** Bugünden itibaren bir sonraki aynı yıllık açılışa kaç gün kaldı (İstanbul günü). */
function daysUntilSeasonStart(startMonth: number, startDay: number, now: Date): number {
  const today = istanbulYmd(now)
  const y = parseInt(today.slice(0, 4), 10)
  const mm = String(startMonth).padStart(2, '0')
  const dd = String(startDay).padStart(2, '0')
  let eventYmd = `${y}-${mm}-${dd}`
  if (noonIstanbulMs(eventYmd) < noonIstanbulMs(today)) {
    eventYmd = `${y + 1}-${mm}-${dd}`
  }
  return Math.round((noonIstanbulMs(eventYmd) - noonIstanbulMs(today)) / 86400000)
}

/** Bu hatırlatmanın bağlı olduğu sezon yılı (açılışın gerçekleşeceği takvim yılı). */
function seasonYearForStart(startMonth: number, startDay: number, now: Date): number {
  const today = istanbulYmd(now)
  const y = parseInt(today.slice(0, 4), 10)
  const mm = String(startMonth).padStart(2, '0')
  const dd = String(startDay).padStart(2, '0')
  let eventYmd = `${y}-${mm}-${dd}`
  if (noonIstanbulMs(eventYmd) < noonIstanbulMs(today)) {
    return y + 1
  }
  return y
}

type CalendarRow = {
  id: string
  species_name: string
  start_month: number
  start_day: number
  notify_days_before: number
}

// ── Günlük cron: N gün kala aktif kullanıcılara bir kez push ─────────────────

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const now = new Date()

    const { data: rows, error: calErr } = await supabase
      .from('fish_season_calendar')
      .select('id, species_name, start_month, start_day, notify_days_before')
      .eq('is_active', true)

    if (calErr) {
      return new Response(
        JSON.stringify({ error: calErr.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const due = (rows ?? []).filter((r: CalendarRow) => {
      const days = daysUntilSeasonStart(r.start_month, r.start_day, now)
      return days === r.notify_days_before
    })

    if (due.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: 'no_seasons_due' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const since30d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const { data: activeUsers } = await supabase
      .from('checkins')
      .select('user_id')
      .gte('created_at', since30d)
      .limit(2000)

    const uniqueUserIds = [...new Set(
      (activeUsers ?? []).map((r: { user_id: string }) => r.user_id),
    )]

    if (uniqueUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: 'no_active_users' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const { data: notifSettings, error: nsErr } = await supabase
      .from('notification_settings')
      .select('user_id, season_reminder')
      .in('user_id', uniqueUserIds)

    if (nsErr) {
      console.warn(
        'notification_settings okunamadı (season_reminder sütunu yok olabilir); filtre uygulanmıyor:',
        nsErr.message,
      )
    }

    const disabledSeason = new Set<string>(
      (notifSettings ?? [])
        .filter((s: { user_id: string; season_reminder: boolean | null }) =>
          s.season_reminder === false
        )
        .map((s: { user_id: string }) => s.user_id),
    )

    const eligibleUserIds = uniqueUserIds.filter((id) => !disabledSeason.has(id))

    const senderUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/notification-sender`
    const authHeader = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`

    let sent = 0

    for (const season of due) {
      const seasonYear = seasonYearForStart(season.start_month, season.start_day, now)

      const { data: already } = await supabase
        .from('fish_season_push_log')
        .select('user_id')
        .eq('calendar_id', season.id)
        .eq('season_year', seasonYear)

      const sentSet = new Set<string>(
        (already ?? []).map((r: { user_id: string }) => r.user_id),
      )

      const title = '📅 Sezon hatırlatması'
      const body =
        `${season.species_name} sezonu ${season.notify_days_before} gün sonra açılıyor. Hazırlan! 🎣`

      const batchSize = 40
      for (let i = 0; i < eligibleUserIds.length; i += batchSize) {
        const batch = eligibleUserIds.slice(i, i + batchSize)
        await Promise.allSettled(
          batch.map(async (uid) => {
            if (sentSet.has(uid)) return
            try {
              // Önce log: çift cron / yarışta yalnızca bir kez push (unique ihlal = atla).
              const { error: insErr } = await supabase.from('fish_season_push_log').insert({
                user_id: uid,
                calendar_id: season.id,
                season_year: seasonYear,
              })
              if (insErr) {
                if (insErr.code === '23505') return
                console.error('fish_season_push_log insert:', insErr.message)
                return
              }
              let pushOk = false
              try {
                const res = await fetch(senderUrl, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json', Authorization: authHeader },
                  body: JSON.stringify({
                    user_id: uid,
                    title,
                    body,
                    data: {
                      type: 'season_reminder',
                      calendar_id: season.id,
                      species_name: season.species_name,
                      season_year: String(seasonYear),
                    },
                    force: true,
                  }),
                })
                pushOk = res.ok
                if (!pushOk) {
                  console.error('notification-sender HTTP:', await res.text())
                }
              } catch (fe) {
                console.error('notification-sender ağ hatası:', fe)
              }
              if (!pushOk) {
                await supabase
                  .from('fish_season_push_log')
                  .delete()
                  .eq('user_id', uid)
                  .eq('calendar_id', season.id)
                  .eq('season_year', seasonYear)
                return
              }
              sentSet.add(uid)
              sent++
            } catch (e) {
              console.error(`season-reminder gönderilemedi (${uid}):`, e)
            }
          }),
        )
      }
    }

    return new Response(
      JSON.stringify({ success: true, sent, seasons_due: due.length }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('season-reminder-push hata:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
