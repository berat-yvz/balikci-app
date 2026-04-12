import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Open-Meteo → weather_cache (12 kıyı bölgesi).
 * pg_cron ile her saat başı tetiklenir; istemci doğrudan Open-Meteo çağırmaz.
 *
 * data_json şeması: { source: 'open_meteo_v1', hourly: [...], current: {...} }
 */

const REGIONS: Record<string, { lat: number; lng: number }> = {
  istanbul: { lat: 41.015, lng: 28.979 },
  izmir: { lat: 38.423, lng: 27.143 },
  antalya: { lat: 36.896, lng: 30.713 },
  trabzon: { lat: 41.005, lng: 39.716 },
  canakkale: { lat: 40.144, lng: 26.406 },
  bodrum: { lat: 37.034, lng: 27.43 },
  fethiye: { lat: 36.621, lng: 29.116 },
  sinop: { lat: 42.023, lng: 35.153 },
  samsun: { lat: 41.286, lng: 36.33 },
  mersin: { lat: 36.812, lng: 34.641 },
  mugla: { lat: 37.215, lng: 28.363 },
  balikesir: { lat: 39.649, lng: 27.889 },
}

/** WMO weathercode (Open-Meteo) — kısa balıkçı özeti (Flutter FishingWeatherUtils ile uyumlu niyet). */
function fishingSummaryWmo(temp: number, wind: number, code: number): string {
  if (wind > 40) return 'Deniz patlak, çıkma ⚠️'
  if (code >= 95) return 'Fırtına var, bugün balık yok ⛈️'
  if (code >= 45 && code <= 48) return 'Sis var, tekneyle dikkatli ol 🌫️'
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return temp < 15
      ? 'Soğuk ve yağışlı, istavrit günü 🌧️'
      : 'Hafif yağmur, kıyıdan oltaya çık 🎣'
  }
  if (wind < 15 && temp >= 18 && temp <= 24) return 'Bugün hava tam lüfer havası ✓'
  if (wind < 10 && temp > 24) return 'Sıcak ve sakin, derin sularda ara 🐟'
  if (temp >= 10 && temp < 16 && wind < 20) return 'Serin hava, çipura ve levrek aktif 🎣'
  if (wind < 20 && code === 0) return 'Açık hava, balıkçılık için uygun ✓'
  if (wind >= 20 && wind <= 35) return 'Rüzgarlı, kıyıda kalmak daha iyi ⚠️'
  return 'Koşulları değerlendir, ortalama bir gün'
}

type HourlyPoint = {
  time: string
  temperature: number
  windspeed: number
  precipitation: number
  weather_code: number
  cloud_cover: number | null
  visibility_m: number | null
  wave_height: number | null
  sea_surface_temperature: number | null
  ocean_current_velocity: number | null
  ocean_current_direction: number | null
}

async function fetchJson(url: string): Promise<Record<string, unknown>> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return (await res.json()) as Record<string, unknown>
}

function mergeOpenMeteo(
  lat: number,
  lng: number,
  forecast: Record<string, unknown>,
  marine: Record<string, unknown> | null,
): { hourly: HourlyPoint[]; current: HourlyPoint } {
  const fh = forecast['hourly'] as Record<string, unknown>
  const times = fh['time'] as string[]
  const temps = fh['temperature_2m'] as number[]
  const winds = fh['windspeed_10m'] as number[]
  const precips = fh['precipitation'] as number[]
  const codes = fh['weathercode'] as number[]
  const clouds = (fh['cloudcover'] as number[] | undefined) ?? []
  const vis = (fh['visibility'] as number[] | undefined) ?? []

  let mh: Record<string, unknown> | null = null
  if (marine) {
    mh = marine['hourly'] as Record<string, unknown>
  }

  const wave = mh ? (mh['wave_height'] as (number | null)[] | undefined) ?? [] : []
  const sst = mh
    ? (mh['sea_surface_temperature'] as (number | null)[] | undefined) ?? []
    : []
  const ocV = mh
    ? (mh['ocean_current_velocity'] as (number | null)[] | undefined) ?? []
    : []
  const ocD = mh
    ? (mh['ocean_current_direction'] as (number | null)[] | undefined) ?? []
    : []

  const hourly: HourlyPoint[] = []
  const n = times.length
  const now = Date.now()

  for (let i = 0; i < n; i++) {
    hourly.push({
      time: times[i],
      temperature: Number(temps[i] ?? 0),
      windspeed: Number(winds[i] ?? 0),
      precipitation: Number(precips[i] ?? 0),
      weather_code: Number(codes[i] ?? 0),
      cloud_cover: i < clouds.length ? (clouds[i] ?? null) : null,
      visibility_m: i < vis.length ? (vis[i] ?? null) : null,
      wave_height: i < wave.length ? (wave[i] ?? null) : null,
      sea_surface_temperature: i < sst.length ? (sst[i] ?? null) : null,
      ocean_current_velocity: i < ocV.length ? (ocV[i] ?? null) : null,
      ocean_current_direction: i < ocD.length ? (ocD[i] ?? null) : null,
    })
  }

  let idx = hourly.findIndex((h) => {
    const t = new Date(h.time).getTime()
    return t >= now - 30 * 60 * 1000
  })
  if (idx < 0) idx = 0
  if (idx >= hourly.length) idx = hourly.length - 1

  return { hourly, current: hourly[idx]! }
}

serve(async (req: Request) => {
  if (req.method !== 'POST' && req.method !== 'OPTIONS') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204 })
  }

  const url = Deno.env.get('SUPABASE_URL')?.trim()
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim()
  if (!url || !key) {
    return new Response(
      JSON.stringify({ error: 'Missing Supabase env' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    )
  }

  const supabase = createClient(url, key)
  const results: string[] = []
  const fetchedAt = new Date().toISOString()

  for (const [regionKey, coords] of Object.entries(REGIONS)) {
    try {
      const { lat, lng } = coords
      const q = `latitude=${lat}&longitude=${lng}&timezone=Europe%2FIstanbul&forecast_days=2`

      const forecastUrl =
        `https://api.open-meteo.com/v1/forecast?${q}&hourly=temperature_2m,windspeed_10m,precipitation,weathercode,cloudcover,visibility`

      const marineUrl =
        `https://marine-api.open-meteo.com/v1/marine?${q}&hourly=wave_height,sea_surface_temperature,ocean_current_velocity,ocean_current_direction`

      const forecast = await fetchJson(forecastUrl)
      let marine: Record<string, unknown> | null = null
      try {
        marine = await fetchJson(marineUrl)
      } catch {
        // marine opsiyonel
      }

      const { hourly, current } = mergeOpenMeteo(lat, lng, forecast, marine)

      const summary = fishingSummaryWmo(
        current.temperature,
        current.windspeed,
        current.weather_code,
      )

      const dataJson = {
        source: 'open_meteo_v1',
        lat,
        lng,
        hourly,
        current,
      }

      const { error } = await supabase.from('weather_cache').upsert(
        {
          region_key: regionKey,
          lat,
          lng,
          data_json: dataJson,
          fishing_summary: summary,
          fetched_at: fetchedAt,
        },
        { onConflict: 'region_key' },
      )

      if (error) throw new Error(error.message)
      results.push(`✓ ${regionKey}`)
    } catch (err) {
      results.push(`✗ ${regionKey}: ${String(err)}`)
    }
  }

  return new Response(JSON.stringify({ ok: true, fetched_at: fetchedAt, results }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
