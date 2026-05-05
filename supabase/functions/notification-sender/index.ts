import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── JWT / OAuth2 yardımcıları ────────────────────────────────────────────────

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')

  const signingInput = `${enc(header)}.${enc(payload)}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  )

  const jwt = `${signingInput}.${btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  )
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenRes.json()
  return tokenData.access_token
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

// ── FCM V1 data: değerler string olmalı ─────────────────────────────────────

function stringifyData(raw: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {}
  for (const [k, v] of Object.entries(raw)) {
    result[k] = String(v)
  }
  return result
}

// ── Gece sessiz modu: 23:00–07:00 İstanbul saati (UTC+3) ───────────────────

function isSilentHours(): boolean {
  const nowUtc = new Date()
  const istHour = (nowUtc.getUTCHours() + 3) % 24
  return istHour >= 23 || istHour < 7
}

// ── Ana handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { user_id, title, body, data, force = false } = await req.json()

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'user_id, title ve body zorunlu' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // FCM token al
    const { data: user, error: userErr } = await supabase
      .from('users')
      .select('fcm_token, username')
      .eq('id', user_id)
      .single()

    if (userErr || !user) {
      return new Response(
        JSON.stringify({ error: 'Kullanıcı bulunamadı' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── notification_settings kontrolü ─────────────────────────────────────
    // Her tür için kullanıcının bildirim tercihini kontrol et.
    // Satır yoksa veya sütun true ise bildirime izin ver (default = açık).
    const notifType: string = (data as Record<string, unknown>)?.type?.toString() ?? 'general'
    const settingsColumnMap: Record<string, string> = {
      checkin_spot_owner: 'checkin_spot_owner',
      checkin_favorite: 'checkin_favorite',
      checkin_nearby: 'checkin_nearby',
      vote_received: 'vote_received',
      rank_up: 'rank_up',
      weather_morning: 'weather_morning',
      morning_weather: 'weather_morning',
      season_reminder: 'season_reminder',
    }
    const settingsCol = settingsColumnMap[notifType]
    if (settingsCol) {
      const { data: notifSettings } = await supabase
        .from('notification_settings')
        .select(`user_id, ${settingsCol}`)
        .eq('user_id', user_id)
        .maybeSingle()
      // Satır varsa ve sütun açıkça false ise bildirimi engelle
      if (notifSettings !== null && notifSettings[settingsCol] === false) {
        return new Response(
          JSON.stringify({ success: false, reason: 'user_preference_disabled' }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
    }

    // ── Force bildirimler için ayrı günlük sınır (2/gün) ───────────────────
    if (force) {
      const todayStart = new Date()
      todayStart.setUTCHours(0, 0, 0, 0)
      const { count: forceCount } = await supabase
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user_id)
        .in('type', ['rank_up', 'weather_morning', 'season_reminder'])
        .gte('created_at', todayStart.toISOString())

      if ((forceCount ?? 0) >= 2) {
        return new Response(
          JSON.stringify({ success: false, reason: 'force_daily_limit_reached' }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
    }

    // ── Günlük 5 bildirim limiti ────────────────────────────────────────────
    if (!force) {
      const todayStart = new Date()
      todayStart.setUTCHours(0, 0, 0, 0)
      const { count } = await supabase
        .from('notifications')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user_id)
        .gte('created_at', todayStart.toISOString())

      if ((count ?? 0) >= 5) {
        return new Response(
          JSON.stringify({ success: false, reason: 'daily_limit_reached' }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
    }

    // FCM token yoksa sadece in-app kayıt yap
    if (!user.fcm_token) {
      await supabase.from('notifications').insert({
        user_id,
        type: (data as Record<string, unknown>)?.type ?? 'general',
        title,
        body,
        data_json: data ?? {},
      })
      return new Response(
        JSON.stringify({ success: true, push: false, reason: 'no_fcm_token' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // ── Gece sessiz mod: 23:00–07:00 İstanbul saatinde push gönderilmez ───────
    if (!force && isSilentHours()) {
      await supabase.from('notifications').insert({
        user_id,
        type: (data as Record<string, unknown>)?.type ?? 'general',
        title,
        body,
        data_json: data ?? {},
      })
      return new Response(
        JSON.stringify({ success: true, push: false, reason: 'silent_hours' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // Service account ile OAuth2 token al
    const b64 = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_B64')!
    const serviceAccount = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)),
      ),
    )
    const accessToken = await getAccessToken(serviceAccount)

    // FCM V1 API — data değerleri string olmalı
    const fcmData = stringifyData({
      type: 'general',
      ...(data ?? {}),
    })

    const projectId: string = serviceAccount.project_id
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: user.fcm_token,
            notification: { title, body },
            data: fcmData,
            android: {
              notification: {
                sound: 'default',
                channel_id: 'balikci_channel',
              },
            },
            apns: {
              payload: { aps: { sound: 'default' } },
            },
          },
        }),
      },
    )

    const fcmBody = await fcmRes.json()

    // FCM başarısız olsa bile in-app bildirim kaydet
    const pushOk = fcmRes.ok
    if (!pushOk) {
      console.error('FCM gönderimi başarısız:', JSON.stringify(fcmBody))
    }

    // In-app notification DB satırı
    const { error: insertErr } = await supabase.from('notifications').insert({
      user_id,
      type: fcmData.type ?? 'general',
      title,
      body,
      data_json: data ?? {},
    })

    if (insertErr) {
      console.error('Notification DB kayıt hatası:', insertErr.message)
    }

    return new Response(
      JSON.stringify({ success: true, push: pushOk, fcm: fcmBody }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('notification-sender hata:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})
