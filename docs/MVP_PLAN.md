# Balıkçı Super App — MVP Özellik Planı

> Bu doküman MVP fazındaki tüm özelliklerin teknik detaylarını içerir.
> Her özellik geliştirilirken bu dosya referans alınmalıdır.

> **Güncel kod özeti ve sıradaki adımlar:** [PROJECT_STATUS.md](PROJECT_STATUS.md)

---

## Özellik Listesi

| Kod | Özellik | Durum |
|-----|---------|-------|
| M-01 | Hesap Girişi & Onboarding | 🟡 Uygulama tarafı tamam (prod doğrulama bekliyor) |
| M-02 | Harita & Mera Sistemi | 🔄 Devam Ediyor (H3 temel tamam) |
| M-03 | Anlık Check-in & Doğrulama | ⏳ Bekliyor |
| M-04 | Hava Durumu & Cache | ⏳ Bekliyor |
| M-05 | Balık Günlüğü | ⏳ Bekliyor |
| M-06 | Puan, Rütbe & Motivasyon | ⏳ Bekliyor |
| M-07 | Düğüm & Takım Rehberi | ⏳ Bekliyor |
| M-08 | Offline Harita İndirme | ⏳ Bekliyor |
| M-09 | Push Bildirim Sistemi | ⏳ Bekliyor |

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
onboarding_screen.dart
  ├── step_location.dart    (konum izni)
  ├── step_notification.dart (FCM izni / bildirim)
  └── step_first_spot.dart  (hoş geldin + onboarding bitişi)
main_shell.dart             → /home (şu an içinde MapScreen)
```
(Router mantığı `lib/app/router.dart` içindedir; ayrı `auth_gate.dart` dosyası yoktur. Güncel özet: [PROJECT_STATUS.md](PROJECT_STATUS.md).)

---

## M-02 — Harita & Mera Sistemi

### Kodda güncel durum (repo ile senkron)

- **H3 (harita temeli):** Uygulandı — `MapScreen` (FlutterMap + OSM), marker cluster, `flutter_map_tile_caching`, `SpotRepository` + Drift `local_spots` (şema sürümü 2), `SpotDetailSheet` salt okunur, `privacy_level` pin renkleri. `/home` → `MainShell` → `MapScreen`; `/map` rotası ayrıca mevcut.
- **H4 (mera yönetimi):** `add_spot_screen` (ekle + `spotToEdit` ile güncelle), `pick_spot_location_screen`, `/map/edit-spot`; `spot_detail_sheet` yol tarifi + sahip **Düzenle**; haritada **Mera ekle** FAB. **Dükkan verisi ve haritada `shops` pinleri** planın sonuna alındı — FAZ E **H15** ([SPRINT.md](SPRINT.md)).
- **H5–H6:** Planlandı (check-in, Realtime, EXIF/oy).

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
- Tile cache: flutter_map_tile_caching

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
- %70+ doğru oy → güvenilir rapor → tam puan
- %70+ yanlış oy → rapor gizlenir + kullanıcıya -20 puan *(ileriye ertelendi)*

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

### Puan Tablosu
| Eylem | Puan | Koşul |
|-------|------|-------|
| Genel mera paylaşımı | +50 | privacy = public |
| Doğrulanmış check-in | +30 | EXIF onaylı |
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

**Gölge Puan (Edge Function: `shadow-point-calculator`)**
```
Yeni check-in + av kaydı geldi
    ↓
O merayı daha önce "public" paylaşanları bul
    ↓
Her birine +20 gölge puan yaz
    ↓
"Senin sayende X kişi balık tuttu" bildirimi gönder
```

**Mera Muhtarlığı**
- Bir merada en yüksek doğrulanmış rapor sahibi → otomatik "Muhtar"
- Profilde rozet, meranın pin'inde isim gösterilir
- Haftalık yeniden hesaplanır

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

### Teknik Detay
- `flutter_map_tile_caching` ile tile yönetimi
- Zoom 10–16 arası tile'lar indirilir
- Offline iken Drift'teki son mera verileri kullanılır
- Check-in offline yazılır, bağlantı gelince sync edilir

---

## M-09 — Push Bildirim Sistemi

> **Durum:** 🔄 Kısmen tamamlandı

### Bildirim Türleri
| Tür | Tetikleyici | Durum | Örnek |
|-----|------------|-------|-------|
| Favori mera | Check-in → favorileyen kullanıcılar | ✅ | "Favori Meranızda Balık Var!" |
| Mera sahibi | Check-in → spot owner | ✅ | "Meranızda Balık Var!" |
| Bildirim deep-link | Tap → spot_id ile mera açılır | ✅ | — |
| Yakın mera | 2km'de 3+ check-in | ⏳ | "Yakınında 5 kişi balık tutuyor 🎣" |
| Gölge puan | Takipçi av yaptı | ⏳ | "Senin sayende 3 kişi boş dönmedi 🏆" |
| Hava uyarısı | Sabah 06:00 cron | ⏳ | "Bugün hava tam lüfer havası ✓" |
| Sezon hatırlatma | Takvim | ⏳ | "Lüfer sezonu 7 gün sonra açılıyor!" |
| Rütbe yükselme | Puan eşiği | ⏳ | "Tebrikler! Usta rütbesine ulaştın ⚓" |

### Uygulanan Teknik Detaylar
- **JSON Payload:** `{"type":"checkin","spot_id":"..."}` — yerel bildirim ve FCM hem `type` hem `spot_id` taşır
- **Deep-link:** `_navigateFromPayload` → `router.go(AppRoutes.map, extra: spotId)` → `MapScreen(initialSpotId)`
- **Favori bildirimi:** `FavoriteRepository.getUsersWhoFavorited(spotId)` → loop → `NotificationRepository.sendNotification`

### Kalan Kurallar
- Kullanıcı başına günlük maksimum **5 push** (spam engeli) *(ileriye ertelendi)*
- Gece 23:00 – sabah 07:00 arası bildirim gönderilmez *(ileriye ertelendi)*
- Kullanıcı ayarlar ekranından her tür ayrı ayrı kapatılabilir *(UI hazır, backend henüz bağlı değil)*
