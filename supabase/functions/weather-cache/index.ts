import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const REGIONS: Record<string, { lat: number; lng: number }> = {
  istanbul:  { lat: 41.015, lng: 28.979 },
  izmir:     { lat: 38.423, lng: 27.143 },
  antalya:   { lat: 36.896, lng: 30.713 },
  trabzon:   { lat: 41.005, lng: 39.716 },
  canakkale: { lat: 40.144, lng: 26.406 },
  bodrum:    { lat: 37.034, lng: 27.430 },
  fethiye:   { lat: 36.621, lng: 29.116 },
  sinop:     { lat: 42.023, lng: 35.153 },
  samsun:    { lat: 41.286, lng: 36.330 },
  mersin:    { lat: 36.812, lng: 34.641 },
  mugla:     { lat: 37.215, lng: 28.363 },
  balikesir: { lat: 39.649, lng: 27.889 },
}

function getFishingSummary(temp: number, wind: number, code: number): string {
  if (wind > 40) return 'Deniz patlak, çıkma ⚠️'
  if (code >= 200 && code < 300) return 'Fırtına var, bugün balık yok ⛈️'
  if (code >= 700 && code < 800) return 'Sis var, tekneyle dikkatli ol 🌫️'
  if (code >= 500 && code < 600) {
    return temp < 15
      ? 'Soğuk ve yağışlı, istavrit günü 🌧️'
      : 'Hafif yağmur, kıyıdan oltaya çık 🎣'
  }
  if (wind < 15 && temp >= 18 && temp <= 24) return 'Bugün hava tam lüfer havası ✓'
  if (wind < 10 && temp > 24) return 'Sıcak ve sakin, derin sularda ara 🐟'
  if (temp >= 10 && temp < 16 && wind < 20) return 'Serin hava, çipura ve levrek aktif 🎣'
  if (wind < 20 && code === 800) return 'Açık hava, balıkçılık için uygun ✓'
  if (wind >= 20 && wind <= 35) return 'Rüzgarlı, kıyıda kalmak daha iyi ⚠️'
  return 'Koşulları değerlendir, ortalama bir gün'
}

serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const apiKey = Deno.env.get('OPENWEATHER_API_KEY')!
  const results: string[] = []

  for (const [regionKey, coords] of Object.entries(REGIONS)) {
    try {
      const url =
        `https://api.openweathermap.org/data/2.5/weather?lat=${coords.lat}&lon=${coords.lng}&appid=${apiKey}&units=metric`
      const res = await fetch(url)
      const data = await res.json()

      const temp: number = data.main?.temp ?? 0
      const wind: number = (data.wind?.speed ?? 0) * 3.6
      const code: number = data.weather?.[0]?.id ?? 800
      const summary = getFishingSummary(temp, wind, code)

      await supabase.from('weather_cache').upsert({
        region_key: regionKey,
        lat: coords.lat,
        lng: coords.lng,
        data_json: data,
        fishing_summary: summary,
        fetched_at: new Date().toISOString(),
      }, { onConflict: 'region_key' })

      results.push(`✓ ${regionKey}`)
    } catch (err) {
      results.push(`✗ ${regionKey}: ${err}`)
    }
  }

  return new Response(
    JSON.stringify({ updated: results }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
