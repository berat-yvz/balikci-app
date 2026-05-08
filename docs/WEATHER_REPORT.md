# HAVA DURUMU SİSTEM RAPORU

> Analiz tarihi: 2026-05-08  
> Kaynak dosyalar: `supabase/functions/weather-cache/index.ts`, `lib/core/services/weather_service.dart`, `lib/data/models/weather_model.dart`, `lib/data/models/hourly_weather_model.dart`, `lib/features/weather/providers/istanbul_weather_provider.dart`, `lib/features/weather/weather_screen.dart`, `lib/features/balikcim/daily_forecast/daily_forecast_screen.dart`, `lib/core/utils/fishing_score_engine.dart`, `lib/data/local/local_weather.dart`, `assets/fishing/fishing_rules.json`

---

## 1. Open-Meteo API Parametreleri

### 1.1 Forecast API

Edge Function'daki URL (`upsertWeatherRegion` içinde):

```
https://api.open-meteo.com/v1/forecast?
  latitude={lat}&longitude={lng}
  &timezone=Europe%2FIstanbul
  &forecast_days=2
  &hourly=temperature_2m,windspeed_10m,winddirection_10m,
          relativehumidity_2m,precipitation,weathercode,
          cloudcover,visibility,surface_pressure
```

| Parametre | API'ye eklendi mi? | HourlyPoint'te var mı? | HourlyWeatherModel'de var mı? | UI'da görünüyor mu? |
|---|---|---|---|---|
| `temperature_2m` | ✅ | ✅ `temperature` | ✅ `temperature` | ✅ Sıcaklık kartı + grafik |
| `windspeed_10m` | ✅ | ✅ `windspeed` | ✅ `windspeed` | ✅ Rüzgar kartı |
| `winddirection_10m` | ✅ | ✅ `wind_direction` | ✅ `windDirection` | ✅ Rüzgar Yönü kartı (currentHour'dan) |
| `relativehumidity_2m` | ✅ | ✅ `humidity` | ❌ Yok | ⚠️ Yalnızca `WeatherModel.humidity` (current), saatlik değil |
| `precipitation` | ✅ | ✅ `precipitation` | ✅ `precipitation` | ❌ Grid'de tile yok |
| `weathercode` | ✅ | ✅ `weather_code` | ✅ `weatherCode` | ✅ Hero kart emojisi |
| `cloudcover` | ✅ | ✅ `cloud_cover` | ✅ `cloudCover` | ✅ Bulutluluk kartı |
| `visibility` | ✅ | ✅ `visibility_m` | ✅ `visibilityMeters` | ✅ Görüş kartı |
| `surface_pressure` | ✅ | ✅ `surface_pressure` | ❌ Yok | ❌ UI'da gösterilmiyor; yalnızca FishingScoreEngine'e gidiyor |

**Not — `relativehumidity_2m`:** API URL'de var, `HourlyPoint.humidity` olarak saklanıyor ancak `HourlyWeatherModel`'e **aktarılmıyor** (`hourlyFromOpenMeteoV1Bundle` bu alanı atıyor). Nem yalnızca `data_json.current.humidity` → `WeatherModel.humidity` üzerinden tek bir anlık değer olarak geliyor.

**Not — `surface_pressure`:** `HourlyPoint.surface_pressure` değeri her saatlik satıra ekleniyor. Dart tarafında `hourlyFromOpenMeteoV1Bundle` bu alanı **okumakta ve atmaktadır** — basınç yalnızca `data_json.current.surface_pressure` üzerinden `WeatherModel.pressureHpa`'ya aktarılıyor.

### 1.2 Marine API

```
https://marine-api.open-meteo.com/v1/marine?
  latitude={lat}&longitude={lng}
  &timezone=Europe%2FIstanbul
  &forecast_days=2
  &hourly=wave_height,sea_surface_temperature,
          ocean_current_velocity,ocean_current_direction
```

| Parametre | API'ye eklendi mi? | HourlyPoint'te var mı? | HourlyWeatherModel'de var mı? | UI'da görünüyor mu? |
|---|---|---|---|---|
| `wave_height` | ✅ | ✅ `wave_height` | ✅ `waveHeight` | ✅ Dalga kartı (conditional) |
| `sea_surface_temperature` | ✅ | ✅ `sea_surface_temperature` | ✅ `seaSurfaceTemperature` | ✅ Deniz Sıcaklığı kartı (conditional) |
| `ocean_current_velocity` | ✅ | ✅ `ocean_current_velocity` | ✅ `currentVelocity` | ✅ Akıntı kartı (conditional) |
| `ocean_current_direction` | ✅ | ✅ `ocean_current_direction` | ✅ `currentDirection` | ✅ Akıntı yön oku (conditional) |

Marine API başarısız olursa (`try/catch` ile susturuluyor) tüm marine alanları `null` kalıyor. Kullanıcıya hata bilgisi verilmiyor.

### 1.3 API Konfigürasyonu

| Ayar | Değer | Not |
|---|---|---|
| `forecast_days` | `2` | 48 saatlik veri çekiliyor; UI'da yalnızca ilk 24 saat kullanılıyor |
| `timezone` | `Europe/Istanbul` | ✅ Doğru |
| `units` parametresi | ❌ Yok | Open-Meteo varsayılanı: °C, km/h — doğru; ancak açıkça belirtilmemiş |
| Bölge sayısı | 12 kıyı + 39 İstanbul ilçesi = **51 bölge** | Her biri için 2 API çağrısı (forecast + marine) = **102 istek/saat** |
| Paralel istek | ❌ Yok — sıralı `await` döngüsü | 51 bölge sırayla işleniyor; biri başarısız olursa diğerleri devam ediyor |

---

## 2. Veri Parse Zinciri

### 2.1 WeatherModel Alanları

| Alan adı | Dart tipi | fromJson path (open_meteo_v1) | Null olabilir mi? | UI widget'ı |
|---|---|---|---|---|
| `id` | `String` | `json['id']` | ❌ (fallback `''`) | Yok |
| `lat` | `double` | `json['lat']` | ❌ (fallback `0`) | Yok |
| `lng` | `double` | `json['lng']` | ❌ (fallback `0`) | Yok |
| `dataJson` | `Map<String,dynamic>?` | `json['data_json']` | ✅ | Drift path'inde null |
| `temperature` | `double?` | `cur['temperature']` | ✅ | `tempCelsius` getter |
| `windspeed` | `double?` | `cur['windspeed']` | ✅ | `windKmh` getter |
| `windDirection` | `int?` | `cur['wind_direction']` | ✅ | `_WeatherDetailGrid._windDirLabel` |
| `waveHeight` | `double?` | `cur['wave_height']` | ✅ | FishingScoreEngine'e gidiyor |
| `seaSurfaceTemperature` | `double?` | `cur['sea_surface_temperature']` | ✅ | FishingScoreEngine (SST bonus) |
| `precipitation` | `double?` | `cur['precipitation']` | ✅ | FishingScoreEngine kuralları |
| `humidity` | `double?` | `cur['humidity']` | ✅ | Nem kartı |
| `visibilityKm` | `double?` | `cur['visibility_m'] / 1000` | ✅ | Görüş kartı (yedek) |
| `cloudCover` | `double?` | `cur['cloud_cover']` | ✅ | Bulutluluk kartı (yedek) |
| `pressureHpa` | `double?` | `cur['surface_pressure']` | ✅ | FishingScoreEngine |
| `pressureHpa3hAgo` | `double?` | `hourly[idx-3]['surface_pressure']` | ✅ | FishingScoreEngine |
| `_weatherCode` | `int?` | `cur['weather_code']` | ✅ | `weatherCode` getter |
| `fishingSummary` | `String?` | `json['fishing_summary']` | ✅ | Kullanılmıyor (UI'da gösterilmiyor) |
| `fetchedAt` | `DateTime` | `json['fetched_at']` | ❌ non-nullable | "Son güncelleme" etiketi |
| `regionKey` | `String?` | `json['region_key']` | ✅ | İç yönlendirme |

### 2.2 HourlyWeatherModel Alanları

| Alan adı | Dart tipi | fromOpenMeteo param adı | Null olabilir mi? | UI widget'ı |
|---|---|---|---|---|
| `time` | `DateTime` | `timeStr` | ❌ | Saat etiketi |
| `temperature` | `double` | `temperature` | ❌ | Sıcaklık grafiği, saatlik kart |
| `windspeed` | `double` | `windspeed` | ❌ | Saatlik kart alt metin |
| `precipitation` | `double` | `precipitation` | ❌ | FishingScoreEngine |
| `weatherCode` | `int` | `weatherCode` | ❌ | Hava emojisi |
| `cloudCover` | `double?` | `cloudCover` | ✅ | Bulutluluk kartı (birincil) |
| `waveHeight` | `double?` | `waveHeight` | ✅ | Dalga kartı (conditional) |
| `seaSurfaceTemperature` | `double?` | `seaSurfaceTemperature` | ✅ | Deniz Sıcaklığı kartı (conditional) |
| `currentVelocity` | `double?` | `currentVelocity` | ✅ | Akıntı kartı (conditional) |
| `currentDirection` | `double?` | `currentDirection` | ✅ | Akıntı yön oku |
| `visibilityMeters` | `double?` | `visibilityMeters` | ✅ | Görüş kartı (birincil, km'ye çevriliyor) |
| `windDirection` | `int?` | `windDirection` | ✅ | Rüzgar Yönü kartı (birincil) |

**HourlyWeatherModel'de olmayan ama HourlyPoint'te olan alanlar:**
- `humidity` — saatlik nem HourlyWeatherModel'e aktarılmıyor
- `surface_pressure` — saatlik basınç HourlyWeatherModel'e aktarılmıyor

---

## 3. Drift Offline Cache Analizi

### 3.1 LocalWeather Tablo Şeması

| Sütun | Drift tipi | Dart tipi | Primary Key? |
|---|---|---|---|
| `regionKey` | `TextColumn` | `String` | ✅ |
| `tempC` | `RealColumn` (nullable) | `double?` | ❌ |
| `windSpeedKmh` | `RealColumn` (nullable) | `double?` | ❌ |
| `waveHeightM` | `RealColumn` (nullable) | `double?` | ❌ |
| `humidity` | `RealColumn` (nullable) | `double?` | ❌ |
| `cachedAt` | `DateTimeColumn` | `DateTime` | ❌ |

**Toplam 6 sütun** — WeatherModel'in 19 alanının yalnızca 4'ü saklanıyor.

### 3.2 WeatherService Drift Yazma

`fetchRegionalWeatherFromSupabase()` içinde başarılı Supabase fetch sonrası:

| WeatherModel alanı | Drift sütunu |
|---|---|
| `current.temperature` | `tempC` |
| `current.windspeed` | `windSpeedKmh` |
| `current.waveHeight` | `waveHeightM` |
| `current.humidity` | `humidity` |
| `DateTime.now()` (sabit) | `cachedAt` |

### 3.3 WeatherService Drift Okuma

Supabase başarısız olduğunda `localWeather` tablosu okunur ve minimal bir `WeatherModel` oluşturulur:

| Drift sütunu | WeatherModel alanı | Değer |
|---|---|---|
| `cached.tempC` | `temperature` | Drift'ten |
| `cached.windSpeedKmh` | `windspeed` | Drift'ten |
| `cached.waveHeightM` | `waveHeight` | Drift'ten |
| `cached.humidity` | `humidity` | Drift'ten |
| `cached.cachedAt` | `fetchedAt` | Drift'ten (= önceki `DateTime.now()`) |
| `cached.regionKey` | `regionKey` | Drift'ten |
| — | `windDirection` | **`null`** (Drift'te yok) |
| — | `seaSurfaceTemperature` | **`null`** (Drift'te yok) |
| — | `precipitation` | **`null`** (Drift'te yok) |
| — | `visibilityKm` | **`null`** (Drift'te yok) |
| — | `cloudCover` | **`null`** (Drift'te yok) |
| — | `pressureHpa` | **`null`** (Drift'te yok) |
| — | `pressureHpa3hAgo` | **`null`** (Drift'te yok) |
| — | `dataJson` | **`null`** (Drift'e hiç yazılmadı) |
| — | `hourly` listesi | **`[]` boş** (`dataJson` null olduğu için `hourlyFromOpenMeteoV1Bundle` boş döner) |

### 3.4 Yazılan vs Okunan Fark

Supabase'den gelen `WeatherModel` şu alanları içeriyor ama bunlar Drift'e yazılmıyor:

- `windDirection`, `seaSurfaceTemperature`, `precipitation`, `visibilityKm`, `cloudCover`, `pressureHpa`, `pressureHpa3hAgo`, `dataJson` (saatlik liste dahil)

**Sonuç:** Offline fallback `WeatherModel`'i; Drift'te saklanmayan 8 alan için `null` döndürür ve `hourly: []` boş liste üretir. Hava ekranındaki 24 saatlik grafik, saatlik kart satırı ve conditional tile'ların tamamı kaybolur.

---

## 4. fetchedAt ve "Son Güncelleme" Analizi

### 4.1 İnternet VARKEN

1. Edge Function çalışır → `fetchedAt = new Date().toISOString()` → Supabase `weather_cache.fetched_at` sütununa yazılır.
2. Flutter `fetchRegionalWeatherFromSupabase()` → Supabase'den tüm satır çekilir.
3. `WeatherModel.fromJson()` → `fetchedAt = DateTime.parse(json['fetched_at'])` → Edge Function'ın çalıştığı gerçek zaman.
4. Drift'e yazarken: `cachedAt: DateTime.now()` — Dart fetch zamanı, **Edge Function zamanı değil**.
5. UI: `_formatFetchedAt(data.current.fetchedAt)` → Edge Function zamanına göre → **doğru** gösterim.

### 4.2 İnternet YOKKEN (Drift fallback)

1. Supabase isteği başarısız → `catch` bloğuna düşer.
2. Drift'ten okuma: `cached.cachedAt` = Flutter'ın son başarılı Supabase fetch yaptığı `DateTime.now()` anı.
3. `fetchedAt = cached.cachedAt` → `_formatFetchedAt()` bu zamanı "son güncelleme" olarak gösterir.
4. UI: Dart'ın son fetch yaptığı zamana göre hesaplama → **yanıltıcı** gösterim.

### 4.3 Tespit Edilen Sorun: "İnternet yokken '1 dakika önce'"

**Kök neden — `weather_service.dart:44`:**

```dart
cachedAt: DateTime.now(),  // BUG: Edge Function zamanı değil, Dart fetch zamanı
```

**Senaryo:**
- Edge Function 09:00'da çalıştı → `fetched_at = "09:00"` (veri bu anda güncellendi)
- Flutter 09:30'da açıldı → Supabase'den çekti → Drift'e `cachedAt = 09:30` yazdı
- Kullanıcı 09:32'de uçak moduna geçti

| Durum | UI gösterimi | Gerçek durum |
|---|---|---|
| Online | "32 dakika önce" (09:00'a göre) | ✅ Doğru |
| Offline | "2 dakika önce" (09:30'a göre) | ❌ Yanıltıcı — veri 32 dk önce güncellendi |

**"İnternet varken 'Dün güncellendi'" senaryosu:** Supabase Edge Function cron'u 24+ saat başarısız olursa `fetched_at` eskimiş kalır → UI "Dün güncellendi" gösterir. Cron sağlığını izleyen bir mekanizma yok.

**Düzeltme (tek satır):**
```dart
cachedAt: current.fetchedAt, // DateTime.now() yerine
```

---

## 5. UI "Veri Yok" Durumları

| Kart | Veri alanı (öncelik sırasıyla) | İnternet varken | İnternet yokken | Neden farklı? |
|---|---|---|---|---|
| Nem | `weather.humidity` | ✅ Değer gösterir | ✅ Değer gösterir | `humidity` Drift'e yazılıyor |
| Görüş | `weather.visibilityKm` → `currentHour.visibilityKm` | ✅ Değer gösterir | ❌ "Veri yok" | `visibilityKm` Drift'e yazılmıyor; `currentHour` null |
| Bulutluluk | `currentHour.cloudCover` → `weather.cloudCover` | ✅ Değer gösterir | ❌ "Veri yok" | `cloudCover` Drift'e yazılmıyor; ikisi de null |
| Rüzgar Yönü | `currentHour.windDirection` → `weather.windDirection` | ✅ Poyraz / Lodos vb. | ❌ "—" | `windDirection` Drift'e yazılmıyor; ikisi null |
| Dalga | `currentHour.waveHeight` | ✅ Tile görünür | ❌ Tile **tamamen kaybolur** | `if (currentHour?.waveHeight != null)` conditional; offline'da `currentHour` null |
| Deniz Sıcaklığı | `currentHour.seaSurfaceTemperature` | ✅ Tile görünür | ❌ Tile **tamamen kaybolur** | Aynı conditional yapı |
| Akıntı | `currentHour.currentVelocity` | ✅ Tile görünür | ❌ Tile **tamamen kaybolur** | Aynı conditional yapı |
| 24h Grafik | `hoursFromNow` (≥1 eleman) | ✅ Grafik görünür | ❌ "Saatlik veri şu an için yok" | `hourly: []` boş döndüğünden `hoursFromNow` boş |
| Saatlik Kartlar | `hoursFromNow.isNotEmpty` | ✅ Kaydırmalı satır | ❌ Satır tamamen yok | Aynı `hourly: []` sebebi |

**Özet:** İnternet yokken hava ekranı yalnızca sıcaklık hero kartı + nem + "24 saat veri yok" mesajından oluşuyor. 9 bileşenden 7'si kayboluyor.

---

## 6. FishingScoreEngine Hava Bağımlılıkları

| Kural grubu | Gerekli alan | Online | Offline | Kural aktif mi? |
|---|---|---|---|---|
| `hard_stop_rules` — rüzgar | `windKmh` | ✅ | ✅ | ✅ Her zaman |
| `hard_stop_rules` — fırtına kodu | `weatherCode` | ✅ | ⚠️ null → 0 | ⚠️ Offline'da code=0, kural tetiklenmiyor |
| `weather_score_modifiers` — rüzgar | `windKmh` | ✅ | ✅ | ✅ Her zaman |
| `weather_score_modifiers` — dalga | `waveM` (= `waveHeight ?? 0`) | ✅ | ⚠️ null → 0 | ⚠️ Offline'da dalga kuralları kör |
| `weather_score_modifiers` — sıcaklık | `tempC` | ✅ | ✅ | ✅ Her zaman |
| `weather_score_modifiers` — yağış | `precipMm` (= `precipitation ?? 0`) | ✅ | ⚠️ null → 0 | ⚠️ Offline'da yağış kuralları kör |
| `weather_score_modifiers` — deniz SST | `seaC` | ✅ | ❌ null | ❌ Offline'da devre dışı |
| `barometric_pressure_rules` | `pressureTrend`, `pressureHpa` | ✅ | ❌ null | ❌ Offline'da tüm basınç kuralları devre dışı |
| `pre_storm_barometric` | `pressureTrend` + `weatherCode` | ✅ | ❌ | ❌ Offline'da devre dışı |
| `solunar_rules` | `MoonPhaseCalculator` (zamansal) | ✅ | ✅ | ✅ Her zaman |
| **Boğaz — ilkbahar göçü** | `month`, `windDir` (0–90°) | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** |
| **Boğaz — sonbahar göçü** | `month`, `windDir` (0–90°) | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** |
| **Boğaz — kış orkos** | `month`, `windDir` (150–210°) | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** |
| **Boğaz — lodos** | `windDir` (180–220°), `windKmh` | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** — potansiyel −25 puan |
| **Boğaz — kıble** | `windDir` (200–230°), `windKmh` | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** — potansiyel −18 puan |
| **Boğaz — poyraz** | `windDir` (30–60°), `windKmh` | ✅ | ❌ `windDir` null | ❌ **Offline'da devre dışı** — potansiyel +12 puan |
| `pre_post_storm_rules` | `isPreStormWindow`, `isPostStormRecovery*` | ❌ hardcode `false` | ❌ | ❌ **Her zaman devre dışı** (online dahil) |
| `istanbul_migration_rules` | `month` | ✅ | ✅ | ✅ Her zaman |

**Boğaz rüzgar kuralları özeti:** 7 kuraldan 7'si offline'da devre dışı. `_matchOne()` içinde `windDir == null` olduğunda `return false` — doğru davranış ama eksik Drift verisiyle birleşince anlamsız skor üretiliyor.

---

## 7. Tespit Edilen Sorunlar

### 🔴 Kritik

**S1 — Drift'e `dataJson` yazılmıyor; offline'da saatlik tahmin tamamen yok**
- **Dosya:** `lib/core/services/weather_service.dart:37-48`
- **Kullanıcıya etkisi:** İnternet kesilince 24h grafik, saatlik kart satırı, dalga/deniz sıcaklığı/akıntı tile'ları tamamen kayboluyor. Ekranın ~%80'i boşalıyor. 45+ yaş hedef kitle için son derece kötü UX.

**S2 — `windDirection`, `cloudCover`, `visibilityKm`, `precipitation`, `seaSurfaceTemperature`, `pressureHpa` Drift'e yazılmıyor**
- **Dosya:** `lib/data/local/local_weather.dart` (şema), `lib/core/services/weather_service.dart:37-48` (yazma)
- **Kullanıcıya etkisi:** Offline'da FishingScoreEngine tüm Boğaz rüzgar kurallarını, barometrik kuralları ve dalga/yağış kurallarını çalıştıramıyor. Skor potansiyel olarak 50+ puan hatalı hesaplanıyor. UI'da Görüş "Veri yok", Bulutluluk "Veri yok", Rüzgar Yönü "—" gösteriyor.

### 🟠 Yüksek

**S3 — `cachedAt = DateTime.now()` yerine `current.fetchedAt` kullanılmalı**
- **Dosya:** `lib/core/services/weather_service.dart:44`
- **Kullanıcıya etkisi:** Offline "Son güncelleme" etiketi yanıltıcı — veri aslında saatler öncesine ait olsa da "2 dakika önce" gösteriyor.

**S4 — `relativehumidity_2m` ve `surface_pressure` `HourlyWeatherModel`'e aktarılmıyor**
- **Dosya:** `lib/core/services/weather_service.dart:222-243`, `lib/data/models/hourly_weather_model.dart`
- **Kullanıcıya etkisi:** Saatlik nem trendi ve saatlik basınç grafiği UI'da gösterilemiyor. Basınç trendi yalnızca anlık current değerinden hesaplanıyor.

**S5 — Marine API başarısızlığı sessizce yutuluyor**
- **Dosya:** `supabase/functions/weather-cache/index.ts:196-200`
- **Kullanıcıya etkisi:** Dalga/deniz sıcaklığı/akıntı tile'ları sessizce kayboluyor. Kullanıcı neden kaybolduğunu bilemiyor.

### 🟡 Orta

**S6 — `is_pre_storm_window`, `is_post_storm_recovery_*` her zaman `false`**
- **Dosya:** `lib/core/utils/fishing_score_engine.dart:643-647`
- **Kullanıcıya etkisi:** JSON'da tanımlı 3 kural (±8 ile ±18 arası puan, priority 45–75) hiçbir zaman tetiklenmiyor. Fırtına öncesi/sonrası en değerli balık pencereleri skora yansımıyor.

**S7 — Offline'da conditional tile'lar kaybolur, "Veri yok" etiketi gösterilmez**
- **Dosya:** `lib/features/weather/weather_screen.dart:1040-1083`
- **Kullanıcıya etkisi:** Dalga, Deniz Sıcaklığı, Akıntı tile'ları `if` bloğu nedeniyle tamamen kayboluyor; kullanıcı sebebini anlamıyor.

**S8 — `fishingSummary` alanı UI'da hiç gösterilmiyor**
- **Dosya:** `lib/features/weather/weather_screen.dart` (kullanım yok)
- **Kullanıcıya etkisi:** Edge Function'ın ürettiği Türkçe balıkçı özeti (ör. "Bugün hava tam lüfer havası ✓") modelde var ama UI'da gösterilmiyor.

### 🟢 Düşük

**S9 — `forecast_days=2` ama 2. gün verisi kullanılmıyor**
- **Dosya:** `supabase/functions/weather-cache/index.ts:187`
- **Kullanıcıya etkisi:** Gereksiz API quota tüketimi; "Yarın tahmini" özelliği yok.

**S10 — Marine API kara içi ilçeler için de çağrılıyor**
- **Dosya:** `supabase/functions/weather-cache/index.ts:279-286`
- **Kullanıcıya etkisi:** Bağcılar, Esenler gibi ilçeler için anlamsız marine isteği; gereksiz hata logları.

**S11 — Saatlik kart satırında yağış gösterilmiyor**
- **Dosya:** `lib/features/weather/weather_screen.dart:582-647`
- **Kullanıcıya etkisi:** `precipitation` alanı `HourlyWeatherModel`'de mevcut ama saatlik kartlarda gösterilmiyor.

---

## 8. Düzeltme Önerileri

| # | Sorun | Öneri | Efor |
|---|---|---|---|
| S1 | Drift'e `dataJson` yazılmıyor | `LocalWeather` tablosuna `TEXT` kolonlu `dataJson` ekle + Drift migration + yazma/okuma güncelle | Yüksek |
| S2 | Eksik Drift alanları | `LocalWeather` tablosuna `windDirection INT`, `cloudCover REAL`, `visibilityKm REAL`, `precipitation REAL`, `seaSurfaceTemperature REAL`, `pressureHpa REAL` ekle | Orta |
| S3 | `cachedAt` yanlış zaman | `cachedAt: DateTime.now()` → `cachedAt: current.fetchedAt` | Düşük (tek satır) |
| S4 | Saatlik nem/basınç eksik | `HourlyWeatherModel`'e `humidity` ve `surfacePressure` ekle; `hourlyFromOpenMeteoV1Bundle` parse'ını güncelle | Orta |
| S5 | Marine hata sessiz | Edge Function sonuç listesine `marine_error` ekle; istemcide `dataJson.marine_available` bayrağını kontrol et | Orta |
| S6 | `isPreStormWindow` hardcode | `hourlyFromOpenMeteoV1Bundle` sonucunda gelecek 2-4 saatte `weatherCode >= 95` varsa `true` ayarla | Orta |
| S7 | Kayıp tile UX | Conditional tile'ları kaldır; her zaman göster, veri null ise "Veri yok" etiketi kullan | Düşük |
| S8 | `fishingSummary` kullanılmıyor | WeatherHeroCard altında Edge Function özetini fallback olarak göster | Düşük |
| S9 | `forecast_days=2` atıl | `forecast_days=1` yap veya 2. günü "Yarın tahmini" bölümünde göster | Düşük |
| S10 | Marine iç bölge | Kara içi ilçeler için marine API çağrısını atla | Düşük |
| S11 | Saatlik yağış yok | `_HourlyScrollRow` kartına yağış göstergesi (☔) ekle | Düşük |
