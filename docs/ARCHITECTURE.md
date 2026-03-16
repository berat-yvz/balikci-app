# Balıkçı Super App — Teknik Mimari

> Tüm mimari kararlar bu dosyada tanımlanmıştır.
> Yeni bir özellik eklerken bu dosyayı referans al.

---

## Teknoloji Stack

### Frontend
| Katman | Teknoloji | Versiyon |
|--------|-----------|---------|
| Framework | Flutter | 3.x |
| Harita | flutter_map + OpenStreetMap | 7.x |
| Offline Harita | flutter_map_tile_caching | 9.x |
| State Management | Riverpod | 2.x |
| Local DB | Drift | 2.x |
| Navigation | go_router | 14.x |
| HTTP | Dio | 5.x |
| Push Bildirim | Firebase Messaging | 15.x |

### Backend (Tamamı Ücretsiz Tier)
| Servis | Kullanım | Ücretsiz Limit |
|--------|---------|----------------|
| Supabase Auth | Kimlik doğrulama | 50.000 kullanıcı/ay |
| Supabase PostgreSQL | Ana veritabanı | 500 MB |
| Supabase Realtime | Anlık check-in | 2 Gbps |
| Supabase Storage | Fotoğraflar | 1 GB |
| Supabase Edge Functions | İş mantığı | 500K istek/ay |
| Firebase FCM | Push bildirim | Sınırsız |
| OpenWeatherMap | Hava verisi | 1000 istek/gün |

---

## Sistem Mimarisi

```
┌─────────────────────────────────────────┐
│           Flutter App (Client)          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │Riverpod │  │  Drift  │  │go_router│ │
│  │ State   │  │Local DB │  │  Nav    │ │
│  └────┬────┘  └────┬────┘  └─────────┘ │
└───────┼────────────┼───────────────────┘
        │            │ (offline sync)
        ▼            ▼
┌─────────────────────────────────────────┐
│         Supabase Backend                │
│  ┌──────────┐  ┌──────────┐            │
│  │ REST API │  │Realtime  │            │
│  │ (PostgREST)  │Websocket │            │
│  └─────┬────┘  └─────┬────┘            │
│        │              │                │
│  ┌─────▼──────────────▼──────────────┐ │
│  │      PostgreSQL Database          │ │
│  │  (RLS ile güvenli veri erişimi)   │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │      Edge Functions (Deno)        │ │
│  │  weather-cache | exif-verify      │ │
│  │  score-calculator | shadow-point  │ │
│  │  notification-sender              │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │      Supabase Storage             │ │
│  │  fish-photos bucket (max 2MB)     │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         Dış Servisler                   │
│  OpenWeatherMap API  │  Firebase FCM    │
└─────────────────────────────────────────┘
```

---

## Veritabanı Şeması

### users
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  rank TEXT DEFAULT 'acemi' CHECK (rank IN ('acemi','olta_kurdu','usta','deniz_reisi')),
  total_score INTEGER DEFAULT 0,
  sustainability_score INTEGER DEFAULT 0,
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### fishing_spots
```sql
CREATE TABLE fishing_spots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  type TEXT CHECK (type IN ('kıyı','kayalık','iskele','tekne','göl','nehir')),
  privacy_level TEXT DEFAULT 'public' CHECK (privacy_level IN ('public','friends','private','vip')),
  description TEXT,
  verified BOOLEAN DEFAULT FALSE,
  muhtar_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### shops
```sql
CREATE TABLE shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  type TEXT CHECK (type IN ('av_bayi','balik_marketi','tekne_kiralama')),
  phone TEXT,
  hours TEXT,
  added_by UUID REFERENCES users(id),
  verified BOOLEAN DEFAULT FALSE
);
```

### checkins
```sql
CREATE TABLE checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  spot_id UUID REFERENCES fishing_spots(id) ON DELETE CASCADE,
  crowd_level TEXT CHECK (crowd_level IN ('yoğun','normal','az','boş')),
  fish_density TEXT CHECK (fish_density IN ('yoğun','normal','az','yok')),
  photo_url TEXT,
  exif_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### checkin_votes
```sql
CREATE TABLE checkin_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checkin_id UUID REFERENCES checkins(id) ON DELETE CASCADE,
  voter_id UUID REFERENCES users(id) ON DELETE CASCADE,
  vote BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(checkin_id, voter_id)
);
```

### fish_logs
```sql
CREATE TABLE fish_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  spot_id UUID REFERENCES fishing_spots(id),
  species TEXT NOT NULL,
  weight DOUBLE PRECISION,
  length DOUBLE PRECISION,
  photo_url TEXT,
  weather_snapshot JSONB,
  is_private BOOLEAN DEFAULT FALSE,
  released BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### shadow_points
```sql
CREATE TABLE shadow_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  giver_id UUID REFERENCES users(id),
  receiver_id UUID REFERENCES users(id),
  source_type TEXT CHECK (source_type IN ('checkin','fish_log')),
  source_id UUID,
  points INTEGER DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### weather_cache
```sql
CREATE TABLE weather_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_key TEXT UNIQUE NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  data_json JSONB NOT NULL,
  fishing_summary TEXT,
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);
```

### notifications
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data_json JSONB,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### follows
```sql
CREATE TABLE follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);
```

---

## Row Level Security (RLS) Politikaları

```sql
-- fishing_spots: public herkes görür, private sadece sahip
ALTER TABLE fishing_spots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public spots visible to all"
  ON fishing_spots FOR SELECT
  USING (privacy_level = 'public');

CREATE POLICY "Friends spots visible to followers"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'friends'
    AND user_id IN (SELECT following_id FROM follows WHERE follower_id = auth.uid())
  );

CREATE POLICY "Private spots only for owner"
  ON fishing_spots FOR SELECT
  USING (privacy_level = 'private' AND user_id = auth.uid());

CREATE POLICY "VIP spots for usta and above"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'vip'
    AND (SELECT rank FROM users WHERE id = auth.uid()) IN ('usta', 'deniz_reisi')
  );

-- fish_logs: gizli kayıtlar sadece sahibine
ALTER TABLE fish_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public logs visible to all"
  ON fish_logs FOR SELECT
  USING (is_private = FALSE);

CREATE POLICY "Private logs only for owner"
  ON fish_logs FOR SELECT
  USING (is_private = TRUE AND user_id = auth.uid());

-- checkin_votes: bir kişi aynı check-in'e bir kez oy verir (UNIQUE constraint ile sağlandı)
ALTER TABLE checkin_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can vote once per checkin"
  ON checkin_votes FOR INSERT
  WITH CHECK (voter_id = auth.uid());

-- follows
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can follow others"
  ON follows FOR INSERT
  WITH CHECK (follower_id = auth.uid());

CREATE POLICY "Users can unfollow"
  ON follows FOR DELETE
  USING (follower_id = auth.uid());

CREATE POLICY "Follows visible to all"
  ON follows FOR SELECT
  USING (true);
```

---

## Flutter Proje Klasör Yapısı

```
lib/
├── main.dart
├── app/
│   ├── router.dart              ← go_router tüm route tanımları
│   └── theme.dart               ← renkler, fontlar, tema sabitleri
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← API URL, timeout, sayfa boyutu
│   │   └── weather_regions.dart ← 12 bölge koordinat listesi
│   ├── services/
│   │   ├── supabase_service.dart   ← Supabase client singleton
│   │   ├── location_service.dart   ← geolocator wrapper
│   │   ├── notification_service.dart ← FCM + local notifications
│   │   └── weather_service.dart    ← hava cache okuma
│   └── utils/
│       ├── exif_helper.dart        ← EXIF okuma yardımcısı
│       ├── geo_utils.dart          ← mesafe hesaplama
│       └── score_utils.dart        ← puan hesaplama yardımcıları
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── spot_model.dart
│   │   ├── checkin_model.dart
│   │   ├── fish_log_model.dart
│   │   └── weather_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── spot_repository.dart
│   │   ├── checkin_repository.dart
│   │   ├── fish_log_repository.dart
│   │   └── user_repository.dart
│   └── local/
│       ├── database.dart           ← Drift DB init ve yönetim
│       ├── local_spot.dart         ← Drift şema: mera
│       ├── local_fish_log.dart     ← Drift şema: günlük
│       └── sync_queue.dart         ← offline sync kuyruğu
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── onboarding/
│   │       ├── onboarding_screen.dart
│   │       ├── step_location.dart
│   │       ├── step_notification.dart
│   │       └── step_first_spot.dart
│   ├── map/
│   │   ├── map_screen.dart
│   │   ├── spot_detail_sheet.dart
│   │   ├── add_spot_screen.dart
│   │   └── widgets/
│   │       ├── spot_marker.dart
│   │       └── weather_card.dart
│   ├── checkin/
│   │   ├── checkin_screen.dart
│   │   ├── vote_widget.dart
│   │   └── checkin_list.dart
│   ├── fish_log/
│   │   ├── log_list_screen.dart
│   │   ├── add_log_screen.dart
│   │   └── stats_screen.dart
│   ├── rank/
│   │   ├── rank_screen.dart
│   │   └── leaderboard_screen.dart
│   ├── knots/
│   │   ├── knots_screen.dart
│   │   ├── knot_detail_screen.dart
│   │   └── knot_filter_widget.dart
│   ├── weather/
│   │   ├── weather_screen.dart
│   │   └── weather_card_widget.dart
│   ├── notifications/
│   │   ├── notification_list_screen.dart
│   │   └── notification_settings_screen.dart
│   └── profile/
│       ├── profile_screen.dart
│       └── settings_screen.dart
└── shared/
    ├── widgets/
    │   ├── app_button.dart
    │   ├── loading_widget.dart
    │   ├── empty_state_widget.dart
    │   └── error_widget.dart
    └── providers/
        ├── auth_provider.dart
        ├── location_provider.dart
        └── connectivity_provider.dart
```

---

## Edge Functions

### weather-cache
- **Tetikleyici:** Cron (her 4 saatte bir)
- **Görev:** 12 bölge için OpenWeatherMap çek, `weather_cache` tablosuna yaz
- **Dosya:** `supabase/functions/weather-cache/index.ts`

### exif-verify
- **Tetikleyici:** Storage trigger (fotoğraf yüklenince)
- **Görev:** GPS + timestamp doğrula, checkin/fish_log kaydını güncelle
- **Dosya:** `supabase/functions/exif-verify/index.ts`

### score-calculator
- **Tetikleyici:** DB trigger (checkin, vote, fish_log insert/update)
- **Görev:** Puan hesapla, users tablosunu güncelle, rütbe kontrol et
- **Dosya:** `supabase/functions/score-calculator/index.ts`

### shadow-point-calculator
- **Tetikleyici:** Yeni fish_log insert
- **Görev:** O merayı paylaşanlara gölge puan yaz, bildirim gönder
- **Dosya:** `supabase/functions/shadow-point/index.ts`

### notification-sender
- **Tetikleyici:** Çeşitli DB triggerlar
- **Görev:** FCM üzerinden push bildirim gönder, günlük 5 limit kontrolü
- **Dosya:** `supabase/functions/notification-sender/index.ts`

---

## Güvenlik Kuralları

### Zorunlu
- Tüm API istekleri HTTPS (Supabase varsayılan)
- JWT: 1 saat access token, 30 gün refresh token
- Tüm tablolarda RLS aktif, varsayılan DENY
- Fotoğraflar signed URL ile servis edilir
- API key ve secret asla client koduna yazılmaz → Edge Function secret

### .gitignore'a Eklenecekler
```
.env
*.env
google-services.json
GoogleService-Info.plist
supabase/.env
```

---

## Tema & Tasarım Sabitleri

```dart
// lib/app/theme.dart

class AppColors {
  static const primary     = Color(0xFF0F6E56);  // teal
  static const primaryLight= Color(0xFFE1F5EE);
  static const secondary   = Color(0xFF185FA5);  // blue
  static const accent      = Color(0xFFEF9F27);  // amber
  static const danger      = Color(0xFFA32D2D);  // red
  static const dark        = Color(0xFF1A1A1A);
  static const muted       = Color(0xFF888780);
  static const background  = Color(0xFFF5F5F3);

  // Pin renkleri
  static const pinPublic   = Color(0xFF1D9E75);
  static const pinFriends  = Color(0xFF378ADD);
  static const pinPrivate  = Color(0xFF888780);
  static const pinVip      = Color(0xFFEF9F27);
}

class AppTextStyles {
  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
}
```
