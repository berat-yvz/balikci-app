# Balıkçı Super App — MVP Özellik Planı

> Bu doküman MVP fazındaki tüm özelliklerin teknik detaylarını içerir.
> Her özellik geliştirilirken bu dosya referans alınmalıdır.

> **Güncel kod özeti ve sıradaki adımlar:** [PROJECT_STATUS.md](PROJECT_STATUS.md)

---

## Özellik Listesi

| Kod | Özellik | Durum |
|-----|---------|-------|
| M-01 | Hesap Girişi & Onboarding | ✅ Uygulama tamam; prod tetikleyici/RLS doğrulaması kullanıcıya bağlı |
| M-02 | Harita & Mera Sistemi | ✅ Harita, CRUD, favori, dükkan pinleri |
| M-03 | Anlık Check-in & Doğrulama | ✅ Check-in + oylama + %70 yanlış gizleme (≥3 oy) |
| M-04 | Hava Durumu & Cache | ✅ Open-Meteo, cache, **Fishing Score Engine** (istemci) |
| M-05 | Balık Günlüğü | ✅ Liste, ekleme, istatistik, offline + Storage |
| M-06 | Puan, Rütbe & Motivasyon | ✅ Profil, rozet, `LeaderboardScreen`, VIP kilidi |
| M-07 | Düğüm & Takım Rehberi | ✅ JSON + ekranlar (Lottie yok) |
| M-08 | Offline Harita İndirme | 🔄 Sadece Drift mera + kuyruk/sync; tile indirme paketi yok |
| M-09 | Push Bildirim Sistemi | ✅ FCM, deep-link, limit, sessiz saat, yakın check-in, sabah/sezon/rütbe |

> Durum: ⏳ Bekliyor | 🔄 Devam Ediyor | ✅ Tamamlandı

---

## M-01 — Hesap Girişi & Onboarding

> Uygulama ve kurulum detayı: [M-01_AUTH_ONBOARDING.md](M-01_AUTH_ONBOARDING.md)

### Teknik Uygulama
- Supabase Auth: e-posta + şifre, Google OAuth
- go_router ile route guard: giriş yapılmamışsa önce `/login` (veya `/register`); oturum açıkken onboarding bitmediyse `/onboarding`
- Oturum: `supabase_flutter` SDK (access/refresh); **Drift şu an oturum token’ı için kullanılmıyor** (ileride `flutter_secure_storage` vb. dokümante edilebilir)
- `public.users` satırı: tercihen `auth.users` tetikleyicisi + RLS ([supabase_fix_mera_insert.sql](supabase_fix_mera_insert.sql))

### Onboarding Akışı (3 Adım)
1. Konum izni isteği — "Yakınındaki meraları görmek için"
2. Bildirim izni — onboarding adımındaki butonla kullanıcı aksiyonu sonrası istenir (app açılışında otomatik istenmez)
3. İlk mera önerisi + "İlk avını kaydet" CTA

İzin adımlarında sayfa **otomatik ilerlemez**; kullanıcı alttaki **İleri** ile sonraki adıma geçer (izin isteğe bağlı, **Atla** ile tüm onboarding atlanabilir).

### Ekran Yapısı (kod ile eşleşen dosyalar)
```
splash_screen.dart          → /splash
login_screen.dart           → /login
register_screen.dart        → /register
onboarding_screen.dart    (konum + bildirim adımları sayfa içi)
  └── step_welcome.dart   (hoş geldin görünümü)
main_shell.dart             → /home (şu an içinde MapScreen)
```
(Router mantığı `lib/app/router.dart` içindedir; ayrı `auth_gate.dart` dosyası yoktur. Güncel özet: [PROJECT_STATUS.md](PROJECT_STATUS.md).)

---

## M-02 — Harita & Mera Sistemi

### Kodda güncel durum (repo ile senkron)

- **H3 (harita temeli):** Uygulandı — `MapScreen` (FlutterMap + OSM), marker cluster, `flutter_map_cancellable_tile_provider`, `SpotRepository` + Drift `local_spots` (**Drift schemaVersion 6**), sheet inline, `privacy_level` pin renkleri. **Ana rota:** `/home` → `MainShell` → `MapScreen`. `AppRoutes.map` sabiti vardır; shell altında ayrı `/map` **go_router kaydı yok** — deep-link `AppRoutes.home` + `extra: spotId`.
- **H4 (mera yönetimi):** `add_spot_screen` (ekle + `spotToEdit` ile güncelle), `pick_spot_location_screen`, `/map/edit-spot`; `spot_detail_sheet` yol tarifi + sahip **Düzenle**; haritada **Mera ekle** FAB. **Dükkan verisi ve haritada `shops` pinleri** planın sonuna alındı — FAZ E **H15** ([SPRINT.md](SPRINT.md)).
- **H5–H6:** Uygulandı — check-in, Realtime, oylama; check-in fotoğrafı yok.

### Teknik Uygulama
- **Harita SDK:** FlutterMap + OpenStreetMap (ücretsiz, API key yok)
- **Cluster:** flutter_map_marker_cluster (1000+ mera için zorunlu)
- **Yol tarifi:** `geo:lat,lng?q=label` URL şeması — API ücreti sıfır
- **Dükkan verileri (`shops`):** Manuel JSON → Supabase import — uygulama zamanlaması **H15** (FAZ E); şema `ARCHITECTURE.md` içinde.

### Gizlilik Katmanları
| privacy_level | Görünürlük | Pin Rengi |
|---------------|-----------|-----------|
| public | Herkes | Yeşil |
| friends | Sadece takipçiler | Mavi |
| private | Sadece sahip | Gri |
| vip | Usta+ rütbe | Altın |

### Performans Kuralları
- Marker cluster zoom level < 12 için aktif
- Mera verileri Drift'te cache, arka planda senkronize
- Kalıcı tile cache: **pubspec’te yok** (M-08 / SPRINT H12)

---

## M-03 — Anlık Check-in & Doğrulama Sistemi

> **Durum:** ✅ Tamamlandı (fotoğraf/EXIF akışı kaldırıldı, UX sadeleştirildi)

### Check-in Akışı (güncel)
1. Kullanıcı konumu ± 500m yarıçap kontrolü (merada mı?)
2. Balık yoğunluğu seçimi: `Yoğun / Normal / Az / Yok`
3. Kalabalık seçimi: `Boş / Sakin / Normal / Kalabalık`
4. Supabase Realtime ile haritadaki pin anlık güncellenir
5. Mera sahibine "Meranızda Balık Var!" bildirimi
6. Mera favorileyen kullanıcılara "Favori Meranızda Balık Var!" bildirimi

> **Not:** Fotoğraf yükleme ve EXIF doğrulama check-in akışından kaldırıldı. `exif-verify` Edge Function yalnızca balık günlüğü için kullanılmaktadır.

### Oylama Sistemi
- Diğer kullanıcılar: `Doğru ✓` / `Yanlış ✗`
- **Gizleme:** en az **3** oy ve **%70+ yanlış** → `CheckinModel.isSuppressedByVotes` (istemci + sunucu tutarlılığı için veri modeli)
- Gizleme sonrası sahibe **-20** puan: `ScoreService.award(..., ScoreSource.wrongReport)` → `score-calculator` Edge Function (ağ hatasında sessiz düşer)

### Veri Yaşam Süresi
- 2 saat sonra rapor "eski" işaretlenir
- Haritada renk solar (canlı → soluk)
- 6 saat sonra haritadan kalkar (DB'de kayıtlı kalır)

---

## M-04 — Hava Durumu & Cache Sistemi

### Çalışma Mantığı
- Sabit bölgeler yok, meralar bazında dinamik cache
- Yeni mera eklendiğinde coğrafi yakınlık kontrolü yapılır
- 25km yarıçapında aktif cache varsa o kullanılır
- Yoksa Open-Meteo'dan yeni veri çekilir

### Cache Mimarisi
Kullanıcı mera detayını açar
    ↓
O meranın lat/lng'si alınır
    ↓
weather_cache'de 25km içinde 1 saatten 
yeni kayıt var mı? (Haversine formülü)
    ↓
Var → cache'den göster (anında, istek yok)
    ↓  
Yok veya eski → Open-Meteo'dan çek → 
cache'e yaz → göster

### Yeni Mera Eklendiğinde
fishing_spots INSERT trigger tetiklenir
    ↓
Edge Function: weather-on-spot-create çalışır
    ↓
25km içinde aktif cache var mı kontrol et
    ↓
Var → spot'a mevcut cache_id'yi bağla
Yok → Open-Meteo'dan çek, yeni cache kaydı oluştur

### Cache Güncelleme
- Her cache kaydı 1 saatte bir güncellenir
- Güncelleme: sadece son 24 saatte aktif merası 
  olan cache kayıtları güncellenir
- Hiç merası kalmayan cache kaydı 7 gün sonra silinir

### Open-Meteo API
URL: https://api.open-meteo.com/v1/forecast
Parametreler:
  &hourly=temperature_2m,windspeed_10m,
  winddirection_10m,precipitation,
  weathercode
  &daily=wave_height_max,
  sea_surface_temperature_mean
  &timezone=Europe/Istanbul
  &forecast_days=1

### Balıkçı Dili Çevirisi (30 Kural)
| Koşul | Çıktı |
|-------|-------|
| windspeed < 15 + wave < 0.5 | "Deniz sakin, ideal gün ✓" |
| windspeed > 40 | "Deniz patlak, çıkma ⚠️" |
| precipitation > 0 + temp < 15 | "Soğuk ve yağışlı, istavrit günü" |
| wave > 1.5 | "Dalgalı, tekneyle çıkma ⚠️" |
| visibility < 1000 | "Sis var, dikkatli ol ⚠️" |
| temp > 28 + windspeed < 10 | "Sıcak ve sakin, derin sularda ara" |
| sea_temp 18-22 + windspeed < 20 | "Su sıcaklığı lüfer için ideal ✓" |

### Fishing Score Engine (istemci, M-04 genişlemesi) ✅

> **Edge Function değil** — skor tamamen uygulama içinde hesaplanır; Supabase’e yazılmaz.

**Çalışma mantığı:** `FishingScoreEngine` (`lib/core/utils/fishing_score_engine.dart`) asset JSON’larını yükler; `calculate(weather, now, moonIllumination)` ile 0–100 skor, etiket, özet, aktif mesajlar ve önerilen tür listesi üretir. Önce **hard-stop** kuralları, ardından hava, mevsim, ay evresi, basınç trendi, solunar ve İstanbul’a özel kurallar (JSON) uygulanır.

**Girdiler:**
- `WeatherModel` — sıcaklık, rüzgar, dalga, yağış, kod, görünürlük vb.; **`pressureHpa`**, **`pressureHpa3hAgo`** (Open-Meteo `surface_pressure` / saatlik dizi)
- `DateTime` — yerel/UTC mantığı motor içinde; mevsimsel kurallar için ay/gün
- `moonIllumination` — `MoonPhaseCalculator.getMoonIllumination(now)` (0–1)
- Solunar pencereler — `MoonPhaseCalculator.getSolunarPeriods` / `isInSolunarPeriod` (İstanbul referans koordinatları)

**Çıktı:** `FishingScore` (`lib/data/models/fishing_score.dart`) — `score`, `label`, `labelColor`, `summary`, `activeMessages`, `suggestedSpecies`, vb.

**Kural kategorileri (JSON + kod):**
- Hava koşulları (modifier / hard-stop)
- Barometrik basınç ve trend (`pressureHpa` vs `pressureHpa3hAgo`)
- Solunar (major/minor pencereler)
- İstanbul’a özel kurallar (`fishing_rules.json` içi)
- Mevsimsel çarpanlar
- Ay evresi (`moon_phase_rules.json`)

**UI bağlantısı:** `fishingScoreProvider` (`lib/shared/providers/fishing_score_provider.dart`) — `fishingScoreEngineProvider` + `istanbulWeatherProvider` birleşimi. **`weather_screen.dart`** içindeki “Bugün balık tutulur mu?” kartı `ref.watch(fishingScoreProvider)` kullanır; hata durumunda `FishingWeatherUtils.getFishingScore` ile yedek kart. Harita **`weather_card.dart`** aynı provider’dan özet alır.

---

## M-05 — Balık Günlüğü

### Kayıt Alanları
```dart
class FishLog {
  String id;
  String userId;
  String? spotId;        // opsiyonel mera bağlantısı
  String species;        // balık türü
  double? weight;        // kg
  double? length;        // cm
  String? photoUrl;      // Supabase Storage
  Map weatherSnapshot;   // kayıt anındaki hava verisi
  bool isPrivate;        // gizli kayıt
  DateTime createdAt;
}
```

### Offline-First Mantığı
```
Kayıt yap
    ↓
Önce Drift (local) → anında göster
    ↓
İnternet varsa → Supabase sync
İnternet yoksa → kuyruğa ekle → bağlantı gelince sync
```

### İstatistik Ekranı
- Toplam av sayısı
- En çok tutulan 3 tür
- En verimli mera
- Aylık av grafiği (bar chart)
- Sürdürülebilirlik skoru

---

## M-06 — Puan, Rütbe & Motivasyon Sistemi

### Sıralama ekranı (kod) ✅
- **`LeaderboardScreen`** — Supabase `users`, `total_score` azalan sırada; isteğe bağlı rütbe filtresi; giriş yapan için global sıra (`my_leaderboard_rank` RPC, repo migration’da).
- **`rank_screen.dart`** — yalnızca `LeaderboardScreen` gösterir; alt navigasyonda “Sıra” sekmesi `/rank`.

### Puan Tablosu
| Eylem | Puan | Koşul |
|-------|------|-------|
| Genel mera paylaşımı | +50 | privacy = public |
| Doğrulanmış check-in | +30 | EXIF onaylı *(check-in akışında EXIF yok; tablo Edge Function sözleşmesi için korunur)* |
| Doğrulanmamış check-in | +15 | — |
| Doğru rapor oyu aldı | +10 | vote = true |
| Gölge puan | +20 | Takipçi o meraya gidip av yaptı |
| Sürdürülebilirlik (balığı saldı) | +40 | Fotoğraflı + EXIF onaylı |
| Günlük kayıt (public) | +10 | — |
| Yanlış rapor cezası | -20 | %70+ yanlış oy |

### Rütbe Sistemi
| Rütbe | Puan | Ayrıcalık |
|-------|------|-----------|
| 🪝 Acemi | 0–499 | Temel özellikler |
| 🎣 Olta Kurdu | 500–1999 | Arkadaş meralarını tam konum görür |
| ⚓ Usta | 2000–4999 | VIP mera erişimi, bayi kuponu |
| 🌊 Deniz Reisi | 5000+ | Tüm meralar tam konum, Muhtar adaylığı |

### Özel Mekanizmalar

**Gölge Puan** — `shadow_points` şeması dokümante; **`shadow-point-calculator` Edge Function bu repoda yok**; bildirim ⏳ (bkz. SPRINT H10).

**Mera Muhtarlığı** — ⏳ Haftalık cron / otomatik atama yok; `muhtar_id` alanı ve UI rozetleri kısmen kullanılabilir

---

## M-07 — Düğüm & Takım Rehberi (Offline)

### İçerik Yapısı
```
assets/
├── knots/
│   ├── knots_data.json     ← tüm düğüm verileri
│   └── animations/
│       ├── palomar.lottie
│       ├── clinch.lottie
│       └── ...
└── tackle/
    └── tackle_data.json    ← takım önerileri
```

### Düğüm JSON Formatı
```json
{
  "id": "palomar",
  "title": "Palomar Düğümü",
  "category": "kanca",
  "difficulty": "kolay",
  "use_cases": ["istavrit", "lüfer", "çipura"],
  "steps": [
    "İpi ikiye katla, 15cm ilmek oluştur",
    "İlmeği kanca deliğinden geçir",
    "Kancayı ilmekten geçir",
    "Her iki uçtan çekerek sıkıştır"
  ],
  "animation": "assets/knots/animations/palomar.lottie"
}
```

### Başlangıç Düğüm Listesi (30 Adet)
Palomar, Improved Clinch, FG, Uni, Double Uni, Surgeons, Blood,
Droşka, Bomber, Snell, Rapala, Spider Hitch, Bimini Twist,
Alberto, PR Bobbin, Loop to Loop, Perfection Loop, Homer Rhode,
Non-Slip Mono, San Diego Jam, Trilene, Berkley Braid,
Davy, Eugene Bend, Figure 8, Orvis, Turle, Half Blood,
Water Knot, Nail Knot

---

## M-08 — Offline Harita İndirme

### Kullanıcı Akışı
1. Haritada "Bölge İndir" butonuna bas
2. İndirmek istediğin alanı çiz (dikdörtgen seçim)
3. Tahmini boyut gösterilir: "~47MB yer kaplayacak"
4. Onayla → arka planda indir
5. İndirme yöneticisinde ilerlemeyi takip et

### Teknik Detay (gerçek durum)
- **Tile indirme:** `flutter_map_tile_caching` **yok**; bölge indirme akışı ⏳
- **Offline:** Drift’te son mera verisi + `sync_queue` / `SyncService`; check-in offline kuyruk ve bağlantı gelince sync ✅ (H12)

---

## M-09 — Push Bildirim Sistemi

> **Durum:** ✅ Kod tarafı tam (Edge Function + FCM + istemci); dağıtım ve cihaz testi kullanıcıya bağlı

### Bildirim Türleri
| Tür | Tetikleyici | Durum | Örnek |
|-----|------------|-------|-------|
| Favori mera | Check-in → favorileyen kullanıcılar | ✅ | "Favori Meranızda Balık Var!" |
| Mera sahibi | Check-in → spot owner | ✅ | "Meranızda Balık Var!" |
| Bildirim deep-link | Tap → `spot_id` ile harita | ✅ | `AppRoutes.home` + `extra` |
| Yakın kullanıcı | `nearby-checkin-notifier` (check-in sonrası ~2 km) | ✅ | Edge Function repo’da |
| Gölge puan | Takipçi av yaptı | ⏳ | EF / bildirim henüz yok |
| Sabah hava | `morning-weather-push` + cron SQL | ✅ | 03:00 UTC ≈ 06:00 İstanbul |
| Sezon hatırlatma | `season-reminder-push` + takvim tabloları | ✅ | Ayar: `season_reminder` |
| Rütbe yükselme | `score-calculator` → `notification-sender` | ✅ | `type: rank_up`, `force: true` |

### Uygulanan Teknik Detaylar
- **JSON Payload:** `{"type":"checkin","spot_id":"..."}` (ve diğer türler)
- **Deep-link:** `NotificationService` → `router.go(AppRoutes.home, extra: spotId)` → `MapScreen(initialSpotId)` *( **`AppRoutes.map` shell rotası kullanılmaz** )*
- **FCM token:** `NotificationService.syncFcmToken` / `UserRepository` → `users.fcm_token`
- **Günlük limit:** `notification-sender` — 5 push / gün, `force` ile muafiyet
- **Sessiz saat:** `notification-sender` — 23:00–07:00 push atlama, in-app kayıt
- **Ayarlar:** `notification_settings_screen` — tür bazlı açık/kapalı (Supabase ile entegre; ayrıntı repository’de)
