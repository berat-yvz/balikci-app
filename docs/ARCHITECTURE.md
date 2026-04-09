# Balıkçı Super App — Teknik Mimari

> Tüm mimari kararlar bu dosyada tanımlanmıştır.
> Yeni bir özellik eklerken bu dosyayı referans al.

> **Anlık uygulama özeti (onboarding, izinler, harita H3):** [PROJECT_STATUS.md](PROJECT_STATUS.md)

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
  weather_cache_id UUID REFERENCES weather_cache(id),
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
  photo_url TEXT,        -- uygulama tarafında artık kullanılmıyor (DB'de saklanıyor)
  exif_verified BOOLEAN DEFAULT FALSE, -- uygulama tarafında artık kullanılmıyor
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
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  temperature DOUBLE PRECISION,
  windspeed DOUBLE PRECISION,
  wind_direction INTEGER,
  wave_height DOUBLE PRECISION,
  sea_surface_temperature DOUBLE PRECISION,
  precipitation DOUBLE PRECISION,
  weather_code INTEGER,
  fishing_summary TEXT,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  region_key TEXT UNIQUE  -- "lat_lng" formatında 
                          -- en yakın 0.25 derece grid
);
```

Hava verisi sabit bölge değil, mera konumuna göre dinamik çekilir. 
25km grid sistemi kullanılır.

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

### spot_favorites
```sql
-- Migration: supabase/migrations/20260409_spot_favorites.sql
CREATE TABLE spot_favorites (
  user_id    uuid NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  spot_id    uuid NOT NULL REFERENCES fishing_spots(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, spot_id)
);
ALTER TABLE spot_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_favorites" ON spot_favorites
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
CREATE INDEX IF NOT EXISTS idx_spot_favorites_spot_id ON spot_favorites (spot_id);
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

CREATE POLICY "Authenticated insert own fishing_spots"
  ON fishing_spots FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated update own fishing_spots"
  ON fishing_spots FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated delete own fishing_spots"
  ON fishing_spots FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

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
│   ├── router.dart              ← go_router; /map extra (spotId) deep-link desteği
│   ├── app_routes.dart          ← route path sabitleri
│   └── theme.dart               ← renkler, fontlar, tema sabitleri
├── core/
│   ├── constants/
│   │   ├── app_constants.dart   ← API URL, timeout, sayfa boyutu
│   │   └── weather_regions.dart ← bölge koordinat listesi
│   ├── services/
│   │   ├── supabase_service.dart    ← Supabase client singleton
│   │   ├── location_service.dart    ← geolocator wrapper
│   │   ├── notification_service.dart← FCM + yerel bildirim; JSON payload (type+spot_id)
│   │   ├── score_service.dart       ← puan verme helper
│   │   └── weather_service.dart     ← Open-Meteo + marine API; 2 günlük veri
│   └── utils/
│       ├── exif_helper.dart         ← EXIF okuma (balık günlüğü için)
│       ├── geo_utils.dart           ← mesafe hesaplama
│       └── score_utils.dart         ← puan hesaplama yardımcıları
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── spot_model.dart
│   │   ├── checkin_model.dart
│   │   ├── fish_log_model.dart
│   │   ├── hourly_weather_model.dart← Open-Meteo saatlik veri (cloudCover dahil)
│   │   ├── notification_model.dart
│   │   └── weather_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── checkin_repository.dart
│   │   ├── favorite_repository.dart ← spot_favorites CRUD (isFavorited, toggle, getFavoriteSpots, getUsersWhoFavorited)
│   │   ├── fish_log_repository.dart
│   │   ├── notification_repository.dart
│   │   ├── spot_repository.dart
│   │   └── user_repository.dart
│   └── local/
│       ├── database.dart            ← Drift DB init (schemaVersion 2)
│       ├── local_spot.dart          ← Drift şema: mera
│       ├── local_fish_log.dart      ← Drift şema: günlük
│       └── sync_queue.dart          ← offline sync kuyruğu
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
│   │   ├── map_screen.dart          ← initialSpotId; _SpotSheetHeader favori butonu
│   │   ├── add_spot_screen.dart
│   │   ├── pick_spot_location_screen.dart
│   │   └── widgets/
│   │       ├── spot_marker.dart
│   │       ├── vote_dialog.dart
│   │       └── weather_card.dart
│   ├── checkin/
│   │   ├── checkin_screen.dart      ← fotoğraf/EXIF kaldırıldı; favori kullanıcılara bildirim
│   │   └── vote_widget.dart
│   ├── fish_log/
│   │   ├── screens/
│   │   │   ├── log_list_screen.dart
│   │   │   └── add_log_screen.dart
│   │   └── stats_screen.dart
│   ├── rank/
│   │   └── rank_screen.dart         ← dikey liste; top-3 madalya UI
│   ├── knots/
│   │   ├── knots_screen.dart
│   │   └── knot_detail_screen.dart
│   ├── weather/
│   │   ├── weather_screen.dart      ← 24s grafik, saat başı otomatik güncelleme, deniz metrikleri
│   │   └── providers/
│   │       └── istanbul_weather_provider.dart ← saat başı timer
│   ├── notifications/
│   │   ├── notification_list_screen.dart ← spot deep-link yönlendirme
│   │   └── notification_settings_screen.dart
│   └── profile/
│       ├── profile_screen.dart      ← _FavoriteSpotsSection (kendi profili)
│       └── settings_screen.dart
└── shared/
    ├── widgets/
    │   ├── rank_badge.dart
    │   ├── empty_state_widget.dart
    │   └── ...
    └── providers/
        ├── auth_provider.dart
        ├── connectivity_provider.dart
        ├── favorite_provider.dart   ← isFavoritedProvider, favoriteSpotsProvider
        ├── fish_log_provider.dart
        ├── follow_provider.dart
        ├── notification_provider.dart
        ├── preferences_provider.dart
        └── user_provider.dart
```

---

## Edge Functions

### weather-cache
- **Tetikleyici:** Cron (her saat başı)
- **Görev:** Saatte bir, son 24 saatte aktif merası olan cache kayıtlarını günceller
- **Dosya:** `supabase/functions/weather-cache/index.ts`

### weather-on-spot-create
- **Tetikleyici:** `fishing_spots` INSERT trigger
- **Görev:** Yeni mera eklendiğinde 25km yakınlık kontrolü, gerekirse Open-Meteo'dan çeker
- **Dosya:** `supabase/functions/weather-on-spot-create/index.ts`

### exif-verify
- **Tetikleyici:** Storage trigger (fotoğraf yüklenince)
- **Görev:** GPS + timestamp doğrula, fish_log kaydını güncelle
- **Not:** Check-in fotoğraf yükleme akışından kaldırıldı; yalnızca balık günlüğü için aktif
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
- **Tetikleyici:** Uygulama tarafından çağrılır (check-in, favori check-in, oy)
- **Görev:** FCM üzerinden push bildirim gönder, günlük 5 limit kontrolü
- **Dosya:** `supabase/functions/notification-sender/index.ts`

---

## Kimlik doğrulama ve kullanıcı profili (M-01)

- **İstemci:** `supabase_flutter` — e-posta/şifre ve Google OAuth (`signInWithOAuth`). PKCE önerilir (`FlutterAuthClientOptions`).
- **Yönlendirme (OAuth):** Mobil için özel şema örn. `balikciapp://login-callback/` — Supabase Dashboard **Redirect URLs** listesinde tanımlı olmalı; Android `AndroidManifest` + iOS `CFBundleURLTypes` ile uygulamaya döner.
- **Profil tablosu:** `public.users.id` = `auth.users.id`. Yeni kullanıcı için satır oluşturma: tercihen `auth.users` üzerinde `AFTER INSERT` tetikleyici ([supabase_fix_mera_insert.sql](supabase_fix_mera_insert.sql)); istemci yalnızca yedek `ensureUserProfile` ile doldurur.
- **RLS:** `public.users` ve `fishing_spots` yazma politikaları aynı dosyada; ek tablolar için [supabase_rls_app_tables.sql](supabase_rls_app_tables.sql). Tetikleyici `SECURITY DEFINER` ile INSERT yapar.
- **Push:** Bildirim izni onboarding bildirim adımında kullanıcı aksiyonu ile alındıktan sonra FCM token `users.fcm_token` alanına yazılır (`notification_service.dart`, `step_notification.dart`). Uygulama açılışında `requestPermission` çağrılmaz; izin zaten varsa `initialize` içinde token senkronu yapılabilir.
- **Onboarding UX:** İzin verildikten sonra sayfa **otomatik ilerlemez**; kullanıcı `onboarding_screen` altındaki **İleri** ile geçer. Konum/bildirim adımlarında `AutomaticKeepAliveClientMixin` ve uygulama `resumed` ile OS izin durumu senkronu; izin verilmiş butonlar pasif kalır. Konum ve bildirim izni **başarısında** yeşil SnackBar yoktur; bildirimde token kaydı hatası veya izin reddi için SnackBar kullanılabilir.
- **Navigasyon:** `go_router` redirect; oturum değişiminde yeniden yönlendirme için `auth.onAuthStateChange` ile `refreshListenable` kullanılır.

Ayrıntılı akış: [M-01_AUTH_ONBOARDING.md](M-01_AUTH_ONBOARDING.md).

---

## Harita ve mera (M-02 H3–H4)

- **Ekran:** `features/map/map_screen.dart` — FlutterMap + OSM tile; `flutter_map_marker_cluster` ile yoğun pin desteği; `flutter_map_tile_caching` ile tile önbelleği.
- **Veri:** `SpotRepository` Supabase `fishing_spots` okur, başarılı yanıtları Drift `local_spots` tablosuna yazar; ağ hatasında `getCachedSpots()` ile offline fallback.
- **UI:** Pin rengi `privacy_level` (public / friends / private / vip); pin tıklanınca `DraggableScrollableSheet` (inline); sahip için "Düzenle", herkes için "Balık Var!" + "Yol Tarifi".
- **Favori butonu:** `_SpotSheetHeader` (`ConsumerWidget`) — `isFavoritedProvider` ile anlık durum, `bookmark`/`bookmark_border` ikonu; `FavoriteRepository.toggleFavorite` tap'ta çağrılır.
- **Deep-link:** `/map` rotası `state.extra` (String `spotId`) kabul eder → `MapScreen(initialSpotId: spotId)`. `_initializeCacheAndLoad` tamamlanınca `_openInitialSpotIfNeeded` ilgili mera için `_selectSpot` çağırır.
- **Giriş noktası:** Onboarding sonrası `/home` → `MainShell` → `MapScreen`; `/map` bildirimlerin doğrudan açtığı rota.
- **H4 (mera):** `add_spot_screen.dart` (ekle + düzenleme modu), `pick_spot_location_screen.dart`; rotalar: `/map/add-spot`, `/map/edit-spot`, `/map/pick-location`. **Dükkan (`shops`) pin katmanı** → H15.
- **Drift:** `AppDatabase` şema sürümü 2; `local_spots` için migrasyon `database.dart` (`verified`, `muhtarId`, `cachedAt`).

## Bildirim Sistemi (M-09)

- **FCM + Yerel bildirim:** `notification_service.dart` — ön plan, arka plan ve kapalı durum için 3 ayrı tap akışı.
- **Payload:** Yerel bildirimler artık sadece `type` değil `{"type":"checkin","spot_id":"..."}` şeklinde JSON payload taşır; `_navigateFromPayload` ile decode edilir.
- **Deep-link:** `checkin` / `vote` türündeki bildirimlere tıklanınca `router.go(AppRoutes.map, extra: spotId)` ile mera doğrudan açılır (hem FCM tap hem bildirim listesi tap'ı).
- **Bildirim listesi:** `notification_list_screen.dart` — `_navigateForNotification` `notification.data['spot_id']`'yi okur; rank → `/rank`, follow → `/profile`, checkin/vote → `/map` + spotId.
- **Favorileme bildirimi:** Check-in anında `FavoriteRepository.getUsersWhoFavorited(spot.id)` ile favorileyen kullanıcılar bulunur, "Favori Meranızda Balık Var!" bildirimi gönderilir (spot sahibi ve check-in yapan hariç).

## Mera Favorileme

- **DB:** `spot_favorites(user_id PK, spot_id PK, created_at)` — RLS: kendi kayıtları; `spot_id` üzerinde index.
- **Repository:** `FavoriteRepository` — `isFavorited`, `toggleFavorite`, `getFavoriteSpots` (join), `getUsersWhoFavorited`.
- **Provider:** `isFavoritedProvider(spotId)` (FutureProvider.autoDispose.family), `favoriteSpotsProvider` (FutureProvider.autoDispose).
- **Profil:** `_FavoriteSpotsSection` — kendi profili (`isSelf == true`) için favori meralar kart listesi; tap'ta `/map?extra=spotId` ile mera açılır.

## Hava Durumu (M-04 / H9)

- **Kaynak:** Open-Meteo (forecast + marine API) — 2 günlük veri (`forecast_days=2`).
- **Saatlik grafik:** Sonraki 24 saat gösterilir; saat başı otomatik güncellenir (kesin saat başı `Timer` ile hesaplanır). Manuel yenileme yok.
- **Metrikler:** `HourlyWeatherModel` — sıcaklık, rüzgar hızı, dalga yüksekliği, deniz yüzey sıcaklığı, akıntı hızı, `cloudCover`. Bulutluluk Open-Meteo `cloudcover` parametresinden çekilir.
- **Detay grid:** Dalga yüksekliği, deniz yüzey sıcaklığı, akıntı hızı ve bulutluluk `_WeatherDetailGrid`'de `currentHour` verisiyle gösterilir.

## Sıralama (Rank)

- **Genel tab:** Tüm kullanıcılar tek dikey listede; ilk 3 için madalya emoji (🥇🥈🥉) ve altın/gümüş/bronz zemin rengi.
- **Haftalık / Bölge tab:** Aynı `_LeaderboardList` yapısı.
- **Bug düzeltme:** `user_repository.dart`'ta varsayılan rank `'bronz'` → `'acemi'` düzeltildi.

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
