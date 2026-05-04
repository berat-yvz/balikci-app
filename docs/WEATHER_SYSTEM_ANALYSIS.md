# Hava Durumu Sistemi — Kapsamlı Analiz Raporu

> Tarih: 2026-05-04 | Analist: Claude Sonnet 4.6 (otomatik kod okuma)
> Durum: **KOD DEĞİŞTİRİLMEDİ** — Yalnızca okuma ve analiz.

---

## Bölüm 1: Sistem Genel Bakış

### Mimari Şema

```
┌─────────────────────────────────────────────────────────────────┐
│                        OPEN-METEO API                           │
│  forecast API (48h)           marine API (48h, opsiyonel)       │
│  temperature_2m, windspeed,   wave_height, SST,                 │
│  precipitation, weathercode,  ocean_current_velocity/direction  │
│  cloudcover, visibility,                                        │
│  surface_pressure                                               │
└───────────────────┬─────────────────────────────────────────────┘
                    │ HTTP (her saat başı, pg_cron ?)
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│           Supabase Edge Function: weather-cache                 │
│  • 12 kıyı bölgesi + 39 İstanbul ilçesi = 51 region_key        │
│  • Forecast + marine birleştirir → HourlyPoint[]                │
│  • fishing_summary üretir (WMO bazlı Türkçe metin)             │
│  • weather_cache tablosuna UPSERT (region_key çakışmada güncelle)│
└───────────────────┬─────────────────────────────────────────────┘
                    │ UPSERT (data_json JSONB)
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│               Supabase: weather_cache tablosu                   │
│  region_key | lat | lng | data_json | fishing_summary | fetched_at │
└───────────────────┬─────────────────────────────────────────────┘
                    │ SELECT (her saat başı Timer + build())
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│               WeatherService (Dart, client-side)                │
│  • fetchRegionalWeatherFromSupabase(regionKey)                  │
│  • hourlyFromOpenMeteoV1Bundle(dataJson) → HourlyWeatherModel[] │
│  • WeatherModel.fromJson() → pressureHpa + pressureHpa3hAgo    │
└─────┬──────────────────────────┬───────────────────────────────┘
      │                          │
      ▼                          ▼
┌──────────────┐      ┌──────────────────────────────────────────┐
│Istanbul      │      │ FishingScoreEngine (JSON kural motoru)   │
│WeatherNotifier│     │ fishing_rules.json + fish_species.json    │
│(AsyncNotifier)│     │ + moon_phase_rules.json                  │
│saat başı poll │     │ calculate(WeatherModel, DateTime, illum) │
└──────┬───────┘      └──────────────────┬───────────────────────┘
       │                                 │
       └──────────────┬──────────────────┘
                      │
                      ▼
          fishingScoreProvider (Provider<AsyncValue<FishingScore>>)
                      │
         ┌────────────┼────────────────┐
         ▼            ▼                ▼
   WeatherScreen  WeatherCard    DailyForecastScreen
   (tam detay)   (harita üstü)  (Balıkçım > Tahmin)
```

### Veri Akışı Özeti

| Adım | Bileşen | Açıklama |
|------|---------|----------|
| 1 | Open-Meteo | Forecast + Marine API |
| 2 | weather-cache Edge Fn | Merge + upsert |
| 3 | Supabase weather_cache | 51 satır, JSONB |
| 4 | WeatherService | Supabase SELECT |
| 5 | IstanbulWeatherNotifier | AsyncNotifier + saat başı Timer |
| 6 | FishingScoreEngine | JSON kural motoru |
| 7 | fishingScoreProvider | Zincir çıktı |
| 8 | UI (3 ekran) | Render |

---

## Bölüm 2: Open-Meteo Entegrasyonu

### Forecast API

```
URL: https://api.open-meteo.com/v1/forecast
     ?latitude={lat}&longitude={lng}
     &timezone=Europe%2FIstanbul
     &forecast_days=2
     &hourly=temperature_2m,windspeed_10m,precipitation,weathercode,
             cloudcover,visibility,surface_pressure
```

### Marine API (Opsiyonel)

```
URL: https://marine-api.open-meteo.com/v1/marine
     ?latitude={lat}&longitude={lng}
     &timezone=Europe%2FIstanbul
     &forecast_days=2
     &hourly=wave_height,sea_surface_temperature,
             ocean_current_velocity,ocean_current_direction
```

### Çekilen Parametreler

| Parametre | API | HourlyPoint | HourlyWeatherModel | WeatherModel |
|-----------|-----|-------------|-------------------|--------------|
| temperature_2m | Forecast | ✓ | ✓ temperature | ✓ temperature |
| windspeed_10m | Forecast | ✓ | ✓ windspeed | ✓ windspeed |
| **winddirection_10m** | **YOK** | **✗** | **✗** | **windDirection = null (sabit!)** |
| precipitation | Forecast | ✓ | ✓ precipitation | ✓ precipitation |
| weathercode | Forecast | ✓ | ✓ weatherCode | ✓ weatherCode |
| cloudcover | Forecast | ✓ | ✓ cloudCover | ✓ cloudCover |
| visibility | Forecast | ✓ | ✓ visibilityMeters | ✓ visibilityKm |
| surface_pressure | Forecast | ✓ | ✗ (yok) | ✓ pressureHpa |
| **humidity** | **YOK** | **✗** | **✗** | **humidity = null (sabit!)** |
| wave_height | Marine | ✓ | ✓ waveHeight | ✓ waveHeight |
| sea_surface_temperature | Marine | ✓ | ✓ seaSurfaceTemperature | ✓ seaSurfaceTemperature |
| ocean_current_velocity | Marine | ✓ | ✓ currentVelocity | ✗ (yok) |
| ocean_current_direction | Marine | ✓ | ✓ currentDirection | ✗ (yok) |

### forecast_days Sınırlaması

- `forecast_days=2` → yalnızca **48 saatlik** veri
- Anlık skor için yeterli; 7 günlük tahmin ekranı için **yetersiz**
- 7 günlük forecast için `forecast_days=7` ve daily endpoint eklenmeli

---

## Bölüm 3: Cache ve Veri Tazeliği

### weather_cache Tablo Yapısı

Kod incelemesinden türetilen şema (migration dosyası bulunamadı):

| Sütun | Tip | Açıklama |
|-------|-----|---------|
| id | UUID/text | PK |
| region_key | text | UNIQUE — bölge tanımlayıcı |
| lat | float | Enlem |
| lng | float | Boylam |
| data_json | JSONB | `{ source, lat, lng, hourly[], current{} }` |
| fishing_summary | text | Türkçe balıkçı özeti |
| fetched_at | timestamptz | Son güncelleme |

**data_json şeması:**
```json
{
  "source": "open_meteo_v1",
  "lat": 41.015,
  "lng": 28.979,
  "current": {
    "time": "2026-05-04T10:00",
    "temperature": 18.2,
    "windspeed": 14.5,
    "precipitation": 0.0,
    "weather_code": 2,
    "cloud_cover": 45,
    "visibility_m": 24000,
    "surface_pressure": 1018.4,
    "wave_height": 0.6,
    "sea_surface_temperature": 16.1,
    "ocean_current_velocity": 0.4,
    "ocean_current_direction": 42.0
  },
  "hourly": [ /* 48 HourlyPoint satırı */ ]
}
```

### Region Key Listesi

- **12 kıyı bölgesi:** istanbul, izmir, antalya, trabzon, canakkale, bodrum, fethiye, sinop, samsun, mersin, mugla, balikesir
- **39 İstanbul ilçesi:** istanbul_ilce_adalar … istanbul_ilce_zeytinburnu
- **Toplam:** 51 satır

### Cron Job Durumu

- Edge Function `weather-cache`: HTTP POST ile tetikleniyor, pg_cron kaydı **kod dosyalarında görülemedi** (config.toml bulunamadı)
- `morning-weather-push` fonksiyonunun yorumunda "pg_cron ile 03:00 UTC'de tetiklenir" yazıyor
- **Cron aktif mi?** Kod üzerinden doğrulanamaz — Supabase Dashboard > Database > Extensions > pg_cron kontrol edilmeli
- Cron **pasifse** veri hiç güncellenmez; gösterilen veri Edge Function'ın son manuel çağrılma zamanından kalır
- Cron **aktifse** veri saatlik; en fazla ~60 dakika eski veri gösterilebilir

### Drift Offline Cache

- `LocalWeather` Drift tablosu: `regionKey`, `tempC`, `windSpeedKmh`, `waveHeightM`, `humidity`, `cachedAt`
- **WeatherService hiçbir yerde Drift'e yazmıyor** — tablo tanımlı ama kullanılmıyor
- Supabase bağlantısı kesildiğinde Drift'ten okuma da yok
- **Offline durumda gerçek fallback YOK** — istanbulWeatherProvider `StateError` fırlatır → `_EmptyWeather` widget'ı gösterilir

### Gerçek Veri Tazeliği

| Durum | En Eski Veri |
|-------|-------------|
| Cron aktif + bağlantı var | ~60 dakika |
| Cron aktif + bağlantı yok | Sonsuz (Drift yok) |
| Cron pasif + bağlantı var | Son manuel tetiklemeden bu yana |
| Cron pasif + bağlantı yok | Uygulama boş ekran gösterir |

---

## Bölüm 4: Provider Zinciri

### Provider Bağımlılık Şeması

```
rootBundle.loadString (3 JSON asset)
         │
         ▼
fishingScoreEngineProvider (FutureProvider<FishingScoreEngine>)
         │
         │          WeatherService.fetchRegionalWeatherFromSupabase('istanbul')
         │                    │
         │                    ▼
         │          IstanbulWeatherNotifier.build()
         │                    │
         │                    ▼
         │          istanbulWeatherProvider (AsyncNotifierProvider<IstanbulWeatherData>)
         │                    │
         └──────────┬─────────┘
                    │  MoonPhaseCalculator.getMoonIllumination(now)
                    ▼
         fishingScoreProvider (Provider<AsyncValue<FishingScore>>)
                    │
       ┌────────────┼────────────────┐
       ▼            ▼                ▼
  WeatherScreen  WeatherCard    DailyForecastScreen
  (istanbulWeatherProvider'ı  (yalnızca fishingScore)
   da ayrıca izler)
```

### Saat Başı Yenileme Mekanizması

```dart
// IstanbulWeatherNotifier._scheduleHourlySupabasePoll()
final now = DateTime.now();
final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
_pollTimer = Timer(nextHour.difference(now), () {
  _silentReload();        // state güncellenir
  _scheduleHourlySupabasePoll();  // bir sonraki saate planla
});
```

- **Gerçek saat başı:** Uygulama açıldığında bir sonraki tam saate kadar bekler
- Açılış 10:47'de → ilk otomatik yenileme 11:00'de
- `_silentReload()`: hata olursa mevcut veriyi korur, state değiştirmez
- Yenileme tetiklendiğinde herhangi bir UI bildirimi yok (kullanıcı görmez)

### Hata Durumu Yönetimi

| Hata Yeri | Davranış |
|-----------|---------|
| istanbulWeatherProvider build() | StateError fırlatır → UI'da _EmptyWeather |
| fishingScoreEngineProvider | AsyncError → fishingScoreProvider hata döner |
| fishingScoreProvider hata | WeatherScreen: _legacyCard (FishingWeatherUtils fallback) |
| WeatherCard hata | FishingWeatherUtils.getFishingScore() ile legacy skor |
| DailyForecastScreen hata | "Bağlantı hatası" + "Tekrar Dene" butonu |
| Saat başı _silentReload hatası | Sessizce görmezden gelir, eski veri kalır |

---

## Bölüm 5: FishingScoreEngine Durumu

### Başlangıç Skoru ve Uygulama Sırası

```
Başlangıç: 50

1. hard_stop_rules     → erken çıkış (result_score döner, devam etmez)
2. weather_score_modifiers  → hava koşulu delta'ları
3. seasonal_modifiers       → mevsim delta'ları
4. moon_phase_rules          → ay fazı delta'ları
5. pre_storm_barometric      → fırtına öncesi özel delta
6. barometric_pressure_rules → basınç trend delta'ları
7. solunar periods           → solunar periyot bonus
8. istanbul_specific_rules.bosphorus_current_rules → Boğaz kuralları
9. istanbul_specific_rules.istanbul_migration_rules → göç kuralları
10. pre_post_storm_rules     → fırtına öncesi/sonrası (daima false!)

Clamp: [0, 100]
```

### Kural Kategorileri ve Delta Aralıkları

| Kategori | Kural Sayısı | Delta Aralığı | Notlar |
|----------|-------------|---------------|--------|
| hard_stop_rules | 2 | result_score=10-15 (mutlak) | Rüzgar ≥55, fırtına WMO |
| weather_score_modifiers | 13 | -18 / +8 | Rüzgar, dalga, sıcaklık, yağış, altın saat |
| seasonal_modifiers | 3 | -4 / +4 | Kış/yaz/geçiş |
| moon_phase_rules | 8 faz | -3 / +5 | JSON'dan |
| pre_storm_barometric | 1 | +18 | falling_fast + fırtına WMO |
| barometric_pressure_rules | 6 | -12 / +15 | Trend bazlı |
| solunar (hesaplama) | — | +6 / +12 | MoonPhaseCalculator |
| bosphorus_current_rules | 8 | -25 / +12 | **Yön kuralları ÇALIŞMIYOR** |
| istanbul_migration_rules | 3 | -10 / +15 | Sadece ay bazlı, yön yok |
| pre_post_storm_rules | 3 | -10 / +18 | **Daima false — hiç ateşlenmiyor** |

### Kritik Sorun: windDirection Daima null

`WeatherModel.fromJson` — Open-Meteo v1 path:
```dart
// Satır 121 — weather_model.dart
windDirection: null,  // ← sabit null, hiç doldurulmuyor
```

`_WeatherContext.from`:
```dart
final windDir = w.windDirection;  // → daima null
```

`_matchOne('wind_direction_deg_min', ...)`:
```dart
if (ctx.windDir == null) return false;  // ← her zaman false döner
```

**Sonuç:** bosphorus_current_rules içindeki TÜM `wind_direction_deg_min/max` koşulları asla eşleşmez:
- İlkbahar göçü K-D rüzgar kuralı → ateşlenmiyor
- Sonbahar göçü K-D rüzgar kuralı → ateşlenmiyor
- Kış güney orkoz kuralı → ateşlenmiyor
- **YENİ:** Lodos (-25) → ateşlenmiyor
- **YENİ:** Kıble (-18) → ateşlenmiyor
- **YENİ:** Keşişleme (-20) → ateşlenmiyor
- **YENİ:** Poyraz (+12) → ateşlenmiyor

Yalnızca `month_in` koşulu olan kurallar (yaz -6, migration rules) çalışmaktadır.

### pressureHpa3hAgo Doğruluğu

`_surfacePressure3hAgo()` mantığı:
1. `current['time']` ile hourly listesinde eşleşen index `idx` bulunur
2. `hourly[idx - 3]` alınır → tam olarak 3 saat önceki saatlik slot
3. Open-Meteo saatlik veri verdiği için slot = saat farkı → **matematiksel olarak doğru**
4. Ancak: Edge Function her saat çalışır ve 48 saatlik veri döner; `idx < 3` ise (gün başı) 3 saat önceki basınç null döner → trend hesaplanamaz

### Solunar Hesaplama

- `MoonPhaseCalculator.getSolunarPeriods(date)`: tam astronomik hesaplama
  - Ay'ın İstanbul'daki yükseklik açısı 10 dakikalık adımlarla hesaplanır
  - Tepe noktası = major period (±1 saat = 2 saat pencere)
  - Lower transit (tepe + 12h) = 2. major period
  - Moonrise/moonset = minor period (±30 dk)
- `isInMajorPeriod(now)` + `isInSolunarPeriod(now)`: bugün ve dün için kontrol eder
- Hesaplama doğru; UTС+3 sabit offset (DST yok, İstanbul için doğru)

### SuggestedSpecies Sıralama Mantığı

```
Puan = moonBonus + (inSeason ? 50 : 8) + (condOk ? 40 : 12)
```
- `condOk`: windKmh ≤ optimal_wind_max VE waveM ≤ optimal_wave_max
- SST bandı (`optimal_sst_min/max`) **kullanılmıyor** — alanlar JSON'da var ama `_rankSpecies` okumaz
- `gear_map` alanları da sıralamada kullanılmıyor — yalnızca görüntüleme için yüklendi

### FishingWeatherUtils vs FishingScoreEngine

| Özellik | FishingWeatherUtils | FishingScoreEngine |
|---------|--------------------|--------------------|
| Kullanım | Fallback (Engine hata verirse) | Birincil |
| Başlangıç skoru | 70 | 50 |
| WMO kodu yorumu | OpenWeather aralıkları (200-800) | Doğru WMO (0-99) |
| Basınç trendi | YOK | Var (6 kural) |
| Solunar | YOK | Var (astronomik) |
| Boğaz kuralları | YOK | Var (ama windDir null!) |
| Kural sayısı | ~8 if/else | 40+ JSON kuralı |
| Çakışma | Engine başarısız → Utils devreye girer | İkisi aynı anda kullanılmaz |

**Not:** Utils'in WMO kodu yorumu yanlış. Örnek: `code >= 200 && code < 300` OpenWeather gök gürültüsü; WMO'da 200 aralığı yok. WMO 95-99 fırtına. Bu fallback skor hatalı üretir.

---

## Bölüm 6: UI Durum Raporu

### Her Ekranda Gösterilen Veriler

| Ekran | Gösterilen | Veri Kaynağı |
|-------|-----------|--------------|
| **WeatherScreen** | Hava emoji + sıcaklık hero | WeatherModel.tempCelsius |
| | Fishing score kartı (score/100, label, 2 mesaj, tür chip'leri) | fishingScoreProvider |
| | Rüzgar km/s | WeatherModel.windKmh |
| | Sıcaklık °C | WeatherModel.tempCelsius |
| | Dalga yüksekliği (koşullu) | HourlyWeatherModel.waveHeight |
| | **Nem** | **WeatherModel.humidity → daima "Veri yok"** |
| | Görüş km | WeatherModel.visibilityKm \|\| HourlyWeatherModel.visibilityKm |
| | Bulutluluk % | HourlyWeatherModel.cloudCover \|\| WeatherModel.cloudCover |
| | Deniz sıcaklığı (koşullu) | HourlyWeatherModel.seaSurfaceTemperature |
| | Akıntı hız+yön (koşullu) | HourlyWeatherModel.currentVelocity/Direction |
| | Saatlik kartlar (24 saat) | HourlyWeatherModel[] |
| | Sıcaklık çizgi grafiği (24h) | HourlyWeatherModel[] |
| | Ay fazı kartı | MoonPhaseCalculator (offline) |
| **WeatherCard** | Sıcaklık + rüzgar + dalga (koşullu) | WeatherModel |
| | Fishing score + label | fishingScoreProvider |
| | Top-1 önerilen tür | fishingScoreProvider.suggestedSpecies[0] |
| **DailyForecastScreen** | Büyük skor (72sp) + label + summary | fishingScoreProvider |
| | Önerilen türler (wrap) | fishingScoreProvider.suggestedSpecies |
| | Aktif mesajlar (Dikkat Et) | fishingScoreProvider.activeMessages |

### Null / "Veri Yok" Durumları

| Veri | Durum | Neden |
|------|-------|-------|
| Nem (humidity) | **Her zaman "Veri yok"** | Open-Meteo forecast'ta humidity parametresi yok |
| Dalga yüksekliği | Marine API başarısız olursa gizli | `if (currentHour?.waveHeight != null)` koşullu |
| Deniz sıcaklığı | Marine API başarısız olursa gizli | Koşullu render |
| Akıntı | Marine API başarısız olursa gizli | Koşullu render |
| Görüş | Open-Meteo'dan geliyor, genelde dolu | Nadiren null |
| Rüzgar yönü | **Her zaman null** | winddirection_10m çekilmiyor |
| Basınç trendi | idx < 3 ise null | Gün başında 3 saat öncesi yok |

### 45+ Yaş Hedef Kitle Uyumluluk Değerlendirmesi

| Kriter | Hedef | Mevcut | Durum |
|--------|-------|--------|-------|
| Minimum dokunma alanı | 56dp | Saatlik kart: 72×110px ✓, Detail tile: ~44px | ⚠️ Detail tile sınırda |
| Hava hero sıcaklık fontu | ≥32sp | h1 (genellikle 32+) ✓ | ✓ |
| Detail grid label fontu | ≥16sp | **13sp** | ✗ |
| Detail grid value fontu | ≥16sp | **14sp** | ✗ |
| Saatlik kart sıcaklık fontu | ≥16sp | **16sp (isNow: 18sp)** | ✓ |
| DailyForecast skor fontu | ≥32sp | **72sp** | ✓ |
| Aktif mesaj fontu | ≥14sp | 15sp | ✓ |
| Önerilen tür chip | ≥12sp | 15sp | ✓ |
| Offline banner | Görünür | 40px yüksek, sarı | ✓ |
| Pull-to-refresh | Var olmalı | **YOK** (hiçbir hava ekranında) | ✗ |

---

## Bölüm 7: Tespit Edilen Sorunlar ve Boşluklar

### [KRİTİK] 1 — winddirection_10m Hiç Çekilmiyor

**Etki:** Tüm yön tabanlı Boğaz kuralları (Lodos, Kıble, Keşişleme, Poyraz, ilkbahar/sonbahar göç+rüzgar kombinasyonları) sessizce ateşlenmiyor. Bunların toplam skor etkisi: -25 ile +12 arasında; yani skor motor çıktısı gerçekten hatalı.

**Etkilenen dosyalar:**
- `supabase/functions/weather-cache/index.ts` → forecastUrl'e `winddirection_10m` eklenmeli
- `supabase/functions/weather-cache/index.ts` → HourlyPoint'e `wind_direction` alanı eklenmeli
- `lib/data/models/weather_model.dart` → `fromJson` open_meteo_v1 path'inde `windDirection` doldurulmalı
- `lib/data/models/hourly_weather_model.dart` → opsiyonel `windDirection` alanı eklenebilir

---

### [KRİTİK] 2 — humidity Parametresi Yok

**Etki:** WeatherScreen > Nem her zaman "Veri yok" gösterir. Arayüzde veri alanı rezerve edilmiş ama içi boş.

**Etkilenen dosyalar:**
- `supabase/functions/weather-cache/index.ts` → forecastUrl'e `relativehumidity_2m` eklenmeli
- `lib/data/models/weather_model.dart` → fromJson open_meteo_v1 path'inde `humidity` doldurulmalı

---

### [KRİTİK] 3 — Drift Offline Cache Bağlantısız

**Etki:** `LocalWeather` Drift tablosu tanımlı ama WeatherService hiçbir yerde bu tabloya yazıp okumaz. Supabase bağlantısı kesildiğinde uygulama hava ekranında boş ekran gösterir.

**Etkilenen dosyalar:**
- `lib/core/services/weather_service.dart` — Drift read/write eklenmeli
- `lib/data/local/local_weather.dart` — mevcut tablo yeterli (alanlar genişletilebilir)

---

### [ÖNEMLİ] 4 — pre_post_storm_rules Daima İnaktif

**Etki:** `is_pre_storm_window`, `is_post_storm_recovery_24h`, `is_post_storm_recovery_48h` bayrakları `_WeatherContext.from` içinde hep `false`. Bu kurallar (+18, -10, +8 delta) hiç ateşlenmiyor.

**Etkilenen dosyalar:**
- `lib/core/utils/fishing_score_engine.dart` → hourly forecast'tan 2-4 saatlik pencere tarama mantığı eklenmeli
- `lib/features/weather/providers/istanbul_weather_provider.dart` → hourly liste provider'a açılabilir

---

### [ÖNEMLİ] 5 — forecast_days=2: 7 Günlük Tahmin İmkânsız

**Etki:** Uygulama ileride 7 günlük tahmin ekranı eklemek isterse mevcut API ayarı yetersiz. Anlık skor için yeterli.

**Etkilenen dosyalar:**
- `supabase/functions/weather-cache/index.ts` → `forecast_days=7` ve `daily` endpoint parametreleri eklenmeli

---

### [ÖNEMLİ] 6 — Cron Job Aktivasyon Durumu Bilinmiyor

**Etki:** Eğer pg_cron kayıtlı değilse veri hiç güncellenmez. Kullanıcı bunu bilemez çünkü `fetched_at` UI'da gösterilmiyor.

**Yapılması gereken:**
- Supabase Dashboard > Database > Extensions > pg_cron kontrol
- `SELECT * FROM cron.job;` ile kayıtlı job'ları doğrula
- UI'da `fetched_at` "Son güncelleme: X dakika önce" olarak gösterilmeli

---

### [ÖNEMLİ] 7 — SuggestedSpecies SST Bandını Kullanmıyor

**Etki:** `fish_species_istanbul.json` içine `optimal_sst_min/max` alanları eklendi (önceki sprint) ama `_rankSpecies()` bu alanları okumaz. SST bazlı tür önerisi mümkün değil.

**Etkilenen dosyalar:**
- `lib/core/utils/fishing_score_engine.dart` → `_rankSpecies()` SST kontrolü eklenmeli

---

### [ÖNEMLİ] 8 — Pull-to-Refresh Yok

**Etki:** Kullanıcı hava verisini manuel yenileyemez. Saat başı Timer dışında tetikleyici yok. Veri eski göründüğünde kullanıcı çaresiz kalır.

**Etkilenen dosyalar:**
- `lib/features/weather/weather_screen.dart` → RefreshIndicator + `ref.invalidate(istanbulWeatherProvider)`
- `lib/features/balikcim/daily_forecast/daily_forecast_screen.dart` → RefreshIndicator

---

### [MINOR] 9 — FishingWeatherUtils Fallback WMO Kodu Yanlış Yorumlar

**Etki:** Engine başarısız olduğunda devreye giren fallback skor, `code >= 200 && code < 300` OpenWeather kod aralıklarını WMO verisi üzerinde uygular. WMO 0-99 arası; fallback kod hiçbir zaman 200+ görmez ve skor her zaman yanlış daldan geçer.

**Etkilenen dosyalar:**
- `lib/core/utils/fishing_weather_utils.dart` → WMO kodu yorumlama düzeltilmeli

---

### [MINOR] 10 — Detail Grid Label/Value Font Boyutları Küçük

**Etki:** `_DetailTile` label: 13sp, value: 14sp. 45+ hedef kitle için 16sp önerilir.

**Etkilenen dosyalar:**
- `lib/features/weather/weather_screen.dart` → `_DetailTile` font boyutları artırılmalı

---

### [MINOR] 11 — fetched_at UI'da Görünmüyor

**Etki:** Kullanıcı verinin ne kadar eski olduğunu bilemez. Cron sorunu varsa stale veri fark edilmez.

---

## Bölüm 8: Önerilen Aksiyon Listesi

| # | Aksiyon | Öncelik | Etkilenen Dosyalar | Tahmini Efor | Sprint İlgisi |
|---|---------|---------|-------------------|-------------|---------------|
| A1 | `winddirection_10m` parametresini Open-Meteo'ya ekle; HourlyPoint, WeatherModel güncelle | 1 — ACİL | weather-cache/index.ts, weather_model.dart, hourly_weather_model.dart | ~2h | Boğaz skor kuralları aktif edilmesi |
| A2 | `relativehumidity_2m` parametresini ekle; humidity alanını doldur | 1 — ACİL | weather-cache/index.ts, weather_model.dart | ~30dk | UI "Veri yok" düzeltme |
| A3 | Drift offline cache bağlantısı: WeatherService Drift'e yaz+oku | 2 — ÖNEMLİ | weather_service.dart, local_weather.dart | ~3h | Offline deneyim |
| A4 | _rankSpecies() SST bandını dahil et | 2 — ÖNEMLİ | fishing_score_engine.dart | ~1h | Tür önerisi kalitesi |
| A5 | Pull-to-refresh (RefreshIndicator) her iki hava ekranına | 2 — ÖNEMLİ | weather_screen.dart, daily_forecast_screen.dart | ~1h | UX |
| A6 | fetched_at UI'da "X dakika önce" olarak göster | 2 — ÖNEMLİ | weather_screen.dart | ~30dk | Veri tazeliği şeffaflığı |
| A7 | pre_post_storm bayraklarını hourly list'ten türet | 3 — SONRA | fishing_score_engine.dart, istanbul_weather_provider.dart | ~4h | Gelecek sprint |
| A8 | FishingWeatherUtils WMO kodu yorumunu düzelt | 3 — SONRA | fishing_weather_utils.dart | ~30dk | Fallback skor doğruluğu |
| A9 | Detail tile font 13/14sp → 16sp | 3 — SONRA | weather_screen.dart | ~10dk | 45+ erişilebilirlik |
| A10 | forecast_days=7 + daily endpoint (7 günlük tahmin ekranı için) | 3 — SONRA | weather-cache/index.ts | ~2h | Gelecek özellik |
| A11 | Supabase Dashboard'da pg_cron job varlığını doğrula | 1 — ACİL | (Dashboard, kod değil) | ~15dk | Cron aktif değilse kritik |

### Sprint Öncelik Sırası

```
Önce yap (bu sprint):
  A11 → cron kontrolü (5 dakika Dashboard kontrolü)
  A1  → winddirection_10m (Boğaz kurallarını aktif eder, en büyük etki)
  A2  → humidity (kolay, 30 dk)
  A5  → pull-to-refresh (UX, 1 saat)
  A6  → fetched_at göster (şeffaflık)

Sonraki sprint:
  A3  → Drift offline cache
  A4  → SST tür önerisi
  A7  → Pre/post storm bayraklar

İleride:
  A8, A9, A10
```

---

*Rapor sonu. Hiçbir kaynak dosya değiştirilmemiştir.*
