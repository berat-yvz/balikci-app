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

function rowToCalendar(r: Record<string, unknown>): CalendarRow | null {
  const id = r.id
  const species = r.species_name
  if (typeof id !== 'string' || typeof species !== 'string') return null
  const startMonth = Number(r.start_month)
  const startDay = Number(r.start_day)
  const notifyDays = Number(r.notify_days_before)
  if (![startMonth, startDay, notifyDays].every((n) => Number.isFinite(n))) return null
  if (startMonth < 1 || startMonth > 12 || startDay < 1 || startDay > 31) return null
  if (notifyDays < 1 || notifyDays > 90) return null
  return {
    id,
    species_name: species,
    start_month: startMonth,
    start_day: startDay,
    notify_days_before: notifyDays,
  }
}

function requireEnv(name: string): string | null {
  const v = Deno.env.get(name)?.trim()
  return v && v.length > 0 ? v : null
}

// ── Günlük cron: N gün kala aktif kullanıcılara bir kez push ─────────────────

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST' && req.method !== 'OPTIONS') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204 })
    }

    // Webhook secret doğrulaması
    const webhookSecret = Deno.env.get('WEBHOOK_SECRET')
    if (webhookSecret) {
      const authHeader = req.headers.get('x-webhook-secret')
      if (authHeader !== webhookSecret) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        })
      }
    }

    const supabaseUrl = requireEnv('SUPABASE_URL')
    const serviceKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !serviceKey) {
      return new Response(
        JSON.stringify({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const supabase = createClient(supabaseUrl, serviceKey)

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

    const rawCalendar = Array.isArray(rows) ? rows : []
    const calendarRows: CalendarRow[] = rawCalendar
      .map((r: unknown) => rowToCalendar(r as Record<string, unknown>))
      .filter((c): c is CalendarRow => c != null)

    const due = calendarRows.filter((r: CalendarRow) => {
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
    const { data: activeUsers, error: checkinsErr } = await supabase
      .from('checkins')
      .select('user_id')
      .gte('created_at', since30d)
      .eq('is_hidden', false)

    if (checkinsErr) {
      console.error('checkins (aktif kullanıcılar):', checkinsErr.message)
      return new Response(
        JSON.stringify({ error: `checkins: ${checkinsErr.message}` }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      )
    }

    const checkinRows = Array.isArray(activeUsers) ? activeUsers : []
    const uniqueUserIds: string[] = [
      ...new Set(
        checkinRows
          .map((r: unknown) =>
            r && typeof r === 'object' && 'user_id' in r &&
            typeof (r as { user_id: unknown }).user_id === 'string'
              ? (r as { user_id: string }).user_id
              : null,
          )
          .filter((id): id is string => id != null && id.length > 0),
      ),
    ]

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

    const baseUrl = supabaseUrl.replace(/\/$/, '')
    const senderUrl = `${baseUrl}/functions/v1/notification-sender`
    const authHeader = `Bearer ${serviceKey}`

    let sent = 0

    for (const season of due) {
      const seasonYear = seasonYearForStart(season.start_month, season.start_day, now)

      const { data: already, error: logReadErr } = await supabase
        .from('fish_season_push_log')
        .select('user_id')
        .eq('calendar_id', season.id)
        .eq('season_year', seasonYear)

      if (logReadErr) {
        console.error(
          'fish_season_push_log okunamadı; bu sezon atlanıyor (çift gönderim riski):',
          logReadErr.message,
        )
        continue
      }

      const sentSet = new Set<string>(
        (already ?? []).map((r: { user_id: string }) => r.user_id),
      )

      const title = '📅 Sezon hatırlatması'
      const body =
        `${season.species_name} sezonu ${season.notify_days_before} gün sonra açılıyor. Hazırlan! 🎣`

      const batchSize = 40
      for (let i = 0; i < eligibleUserIds.length; i += batchSize) {
        const batch = eligibleUserIds.slice(i, i + batchSize)
        const increments = await Promise.all(
          batch.map(async (uid): Promise<number> => {
            if (sentSet.has(uid)) return 0
            try {
              // Önce log: çift cron / yarışta yalnızca bir kez push (unique ihlal = atla).
              const { error: insErr } = await supabase.from('fish_season_push_log').insert({
                user_id: uid,
                calendar_id: season.id,
                season_year: seasonYear,
              })
              if (insErr) {
                if (insErr.code === '23505') return 0
                console.error('fish_season_push_log insert:', insErr.message)
                return 0
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
                return 0
              }
              sentSet.add(uid)
              return 1
            } catch (e) {
              console.error(`season-reminder gönderilemedi (${uid}):`, e)
              return 0
            }
          }),
        )
        sent += increments.reduce((a, b) => a + b, 0)
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
