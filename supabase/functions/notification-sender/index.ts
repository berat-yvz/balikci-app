import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

async function getAccessToken(serviceAccount: any): Promise<string> {
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

  const enc = (obj: any) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const signingInput = `${enc(header)}.${enc(payload)}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput))
  const jwt = `${signingInput}.${btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`

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

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { user_id, title, body, data } = await req.json()

    // FCM token al
    const { data: user, error } = await supabase
      .from('users')
      .select('fcm_token, username')
      .eq('id', user_id)
      .single()

    if (error || !user?.fcm_token) {
      return new Response(
        JSON.stringify({ error: 'FCM token bulunamadı' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // Service account ile access token al
    const b64 = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_B64')!
const serviceAccount = JSON.parse(new TextDecoder().decode(
  Uint8Array.from(atob(b64), c => c.charCodeAt(0))
))
    const accessToken = await getAccessToken(serviceAccount)

    // FCM V1 API ile bildirim gönder
    const projectId = serviceAccount.project_id
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: user.fcm_token,
            notification: { title, body },
            data: data ?? {},
            android: {
              notification: {
                sound: 'default',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
          },
        }),
      },
    )

    const fcmData = await fcmRes.json()

    // Bildirimi DB'ye kaydet
    await supabase.from('notifications').insert({
      user_id,
      type: data?.type ?? 'general',
      title,
      body,
      data_json: data ?? {},
    })

    return new Response(
      JSON.stringify({ success: true, fcm: fcmData }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }
})