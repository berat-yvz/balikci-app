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

// ── Ana handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { user_id, title, body, data } = await req.json()

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
