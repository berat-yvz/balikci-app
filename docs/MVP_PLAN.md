# Balıkçı Super App — MVP Özellik Planı

> Bu doküman MVP fazındaki tüm özelliklerin teknik detaylarını içerir.
> Her özellik geliştirilirken bu dosya referans alınmalıdır.

---

## Özellik Listesi

| Kod | Özellik | Durum |
|-----|---------|-------|
| M-01 | Hesap Girişi & Onboarding | ⏳ Bekliyor |
| M-02 | Harita & Mera Sistemi | ⏳ Bekliyor |
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

### Teknik Uygulama
- Supabase Auth: e-posta + şifre, Google OAuth
- go_router ile route guard: giriş yapılmamışsa `/onboarding` yönlendirmesi
- JWT token Drift'te veya secure storage'da saklanır, offline oturum açık kalır

### Onboarding Akışı (3 Adım)
1. Konum izni isteği — "Yakınındaki meraları görmek için"
2. Bildirim izni — örnek bildirim gösterilerek
3. İlk mera önerisi + "İlk avını kaydet" CTA

### Ekran Yapısı
```
splash.dart
└── auth_gate.dart
    ├── onboarding/
    │   ├── onboarding_step1.dart  (konum izni)
    │   ├── onboarding_step2.dart  (bildirim izni)
    │   └── onboarding_step3.dart  (ilk mera)
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    └── main_shell.dart
```

---

## M-02 — Harita & Mera Sistemi

### Teknik Uygulama
- **Harita SDK:** FlutterMap + OpenStreetMap (ücretsiz, API key yok)
- **Cluster:** flutter_map_marker_cluster (1000+ mera için zorunlu)
- **Yol tarifi:** `geo:lat,lng?q=label` URL şeması — API ücreti sıfır
- **Dükkan verileri:** Manuel JSON → Supabase import

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

### Check-in Akışı
1. Kullanıcı konumu ± 500m yarıçap kontrolü (merada mı?)
2. Balık yoğunluğu seçimi: `Yoğun / Normal / Az / Yok`
3. Opsiyonel fotoğraf (EXIF doğrulama tetiklenir)
4. Supabase Realtime ile haritadaki pin anlık güncellenir

### Oylama Sistemi
- Diğer kullanıcılar: `Doğru ✓` / `Yanlış ✗`
- %70+ doğru oy → güvenilir rapor → tam puan
- %70+ yanlış oy → rapor gizlenir + kullanıcıya -20 puan

### Veri Yaşam Süresi
- 2 saat sonra rapor "eski" işaretlenir
- Haritada renk solar (canlı → soluk)
- 6 saat sonra haritadan kalkar (DB'de kayıtlı kalır)

### EXIF Doğrulama (Edge Function: `exif-verify`)
```
Fotoğraf yüklendi
    ↓
GPS koordinatı çıkar → mera konumu ± 1km ?
    ↓
Timestamp çıkar → şu an ± 30 dakika ?
    ↓
✓ Doğrulandı (2x puan) | ✗ Doğrulanmadı (1x puan, işaret eklenir)
```

---

## M-04 — Hava Durumu & Cache Sistemi

### Cache Mimarisi
```
OpenWeatherMap API
    ↓ (günde 6x, 12 bölge = 72 istek/gün)
Edge Function: weather-cache (cron: her 4 saatte)
    ↓
Supabase: weather_cache tablosu
    ↓
Tüm kullanıcılar (sınırsız, API'ye hiç gitmiyor)
```

### Türkiye Bölge Kodları
```dart
const weatherRegions = {
  'istanbul':    {'lat': 41.015, 'lng': 28.979},
  'izmir':       {'lat': 38.423, 'lng': 27.143},
  'antalya':     {'lat': 36.896, 'lng': 30.713},
  'trabzon':     {'lat': 41.005, 'lng': 39.716},
  'canakkale':   {'lat': 40.144, 'lng': 26.406},
  'bodrum':      {'lat': 37.034, 'lng': 27.430},
  'fethiye':     {'lat': 36.621, 'lng': 29.116},
  'sinop':       {'lat': 42.023, 'lng': 35.153},
  'samsun':      {'lat': 41.286, 'lng': 36.330},
  'mersin':      {'lat': 36.812, 'lng': 34.641},
  'mugla':       {'lat': 37.215, 'lng': 28.363},
  'balikesir':   {'lat': 39.649, 'lng': 27.889},
};
```

### Balıkçı Dili Çevirisi (Kural Tabanlı)
| Koşul | Çıktı |
|-------|-------|
| Rüzgar < 15 km/h + Sıcaklık 18-24°C | "Bugün hava tam lüfer havası ✓" |
| Rüzgar > 40 km/h | "Deniz patlak, çıkma ⚠️" |
| Yağmur + Sıcaklık < 15°C | "Soğuk ve yağışlı, istavrit günü" |
| Sisli + Görüş < 1km | "Sis var, tekneyle çıkma" |
| Sıcaklık > 28°C + Sakin deniz | "Sıcak, derin sularda ara" |

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
Önce Isar (local) → anında göster
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
- Offline iken Isar'daki son mera verileri kullanılır
- Check-in offline yazılır, bağlantı gelince sync edilir

---

## M-09 — Push Bildirim Sistemi

### Bildirim Türleri
| Tür | Tetikleyici | Örnek |
|-----|------------|-------|
| Yakın mera | 2km'de 3+ check-in | "Yakınında 5 kişi balık tutuyor 🎣" |
| Favori mera | Yeni check-in | "Galata Köprüsü'nde hareket var!" |
| Gölge puan | Takipçi av yaptı | "Senin sayende 3 kişi boş dönmedi 🏆" |
| Hava uyarısı | Sabah 06:00 cron | "Bugün hava tam lüfer havası ✓" |
| Sezon hatırlatma | Takvim | "Lüfer sezonu 7 gün sonra açılıyor!" |
| Rütbe yükselme | Puan eşiği | "Tebrikler! Usta rütbesine ulaştın ⚓" |

### Kurallar
- Kullanıcı başına günlük maksimum **5 push** (spam engeli)
- Gece 23:00 – sabah 07:00 arası bildirim gönderilmez
- Kullanıcı ayarlar ekranından her tür ayrı ayrı kapatılabilir
