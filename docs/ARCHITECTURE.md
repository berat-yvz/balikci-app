# Balıkçı Super App — Teknik Mimari

> Tüm mimari kararlar bu dosyada tanımlanmıştır.
> Yeni bir özellik eklerken bu dosyayı referans al.

> **Anlık uygulama özeti (onboarding, izinler, harita H3):** [PROJECT_STATUS.md](PROJECT_STATUS.md)

> **⚠️ CANLI DURUM NOTU (Mayıs 2026):** Bu dosya `docs/Report-04.05.2026/` analizleriyle çapraz doğrulanmıştır. Bilinen kısıtlar ve açıklar ilgili başlıklarda `⚠️` ile işaretlenmiştir. Sistemi olduğu gibi belgeler; planlandığı gibi değil.

---

## Teknoloji Stack

### Frontend
| Katman | Teknoloji | Versiyon |
|--------|-----------|---------|
| Framework | Flutter | 3.x |
| Harita | flutter_map + OpenStreetMap | 7.x |
| Harita (iptal edilebilir tile isteği) | flutter_map_cancellable_tile_provider | 3.x |
| Kalıcı offline tile cache | *(pubspec’te yok; H12’de planlı)* | — |
| State Management | Riverpod | 2.x |
| Local DB | Drift | 2.x |
| Navigation | go_router | 14.x |
| HTTP | Supabase SDK + `http` (weather_service vb.); **dio paketi yok** | — |
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
| Open-Meteo | Hava verisi (forecast + marine) | ücretsiz kullanım politikası |

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
│  │  score-calculator                 │ │
│  │  notification-sender | nearby-*   │ │
│  │  morning-weather | season-reminder│ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │      Supabase Storage             │ │
│  │  fish-photos (2MB; ⚠️ MIME=NULL)  │ │
│  │  users-avatars (2MB; MIME ✅)     │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│         Dış Servisler                   │
│  Open-Meteo API      │  Firebase FCM    │
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
  fish_species TEXT[],   -- migration 20260413_checkins_fish_species.sql ile eklendi
  photo_url TEXT,        -- check-in akışında artık kullanılmıyor (UI kaldırıldı)
  exif_verified BOOLEAN DEFAULT FALSE, -- check-in akışında kullanılmıyor; balık günlüğü için saklanıyor
  is_active BOOLEAN DEFAULT TRUE,
  -- Aşağıdaki kolonlar migration 20260413_vote_rls_and_schema_fix.sql ile eklendi:
  is_hidden BOOLEAN NOT NULL DEFAULT false,  -- topluluk oylamasıyla otomatik gizleme
  true_votes INTEGER NOT NULL DEFAULT 0,     -- trigger ile senkronize
  false_votes INTEGER NOT NULL DEFAULT 0,    -- trigger ile senkronize
  expires_at TIMESTAMPTZ,                    -- geçerlilik süresi (opsiyonel)
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

> **Moderasyon notu:** `is_hidden` alanı `trg_checkin_votes_aggregate` trigger'ı (SECURITY DEFINER) tarafından güncellenir. Eşik: ≥3 oy ve ≥%70 "yanlış" oyu. `SELECT` politikası `is_hidden = false` olanları filtreler. İstemci bu alanı doğrudan güncelleyemez.

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

> **⚠️ BİLİNEN KISİT:** `shadow_points` tablosunda `ROW LEVEL SECURITY` etkin değil. Herhangi bir authenticated kullanıcı bu tablodaki tüm satırları okuyabilir. Ayrıca gölge puanı hesaplayan Edge Function (`shadow-point-calculator`) henüz yazılmamış — tablo şeması var ama puan dağıtım mekanizması yok.

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

Hava verisi sabit bölge değil, mera konumuna göre dinamik çekilir; yakınlık/proxy mantığı `weather_service` ve Edge `weather-cache` ile uyumludur.

**Şema notu:** Bazı ortamlarda `weather_cache` satırı `data_json JSONB` (ör. [supabase_schema.sql](supabase_schema.sql)) olarak tutulur; istemci `WeatherModel` Open-Meteo paketinden **`surface_pressure` → `pressureHpa`**, **`pressureHpa3hAgo`** (trend) ve deniz/saatlik alanları JSON’dan okur. Ayrı `pressure_hpa` kolonu şart değildir. Drift `local_weather` tablosunda basınç yoktur (sıcaklık, rüzgar, dalga, nem, zaman).

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

### fish_season_calendar & fish_season_push_log
Yıllık sezon açılış hatırlatmaları (H10). Takvim satırları yönetilebilir; `season-reminder-push` Edge Function günlük cron ile `notify_days_before` gün kala push atar. Kullanıcı başına sezon yılında tek bildirim `fish_season_push_log` ile garanti edilir.

```sql
-- Migration: supabase/migrations/20260414_fish_season_calendar.sql
CREATE TABLE fish_season_calendar (
  id uuid PRIMARY KEY,
  species_name text NOT NULL,
  start_month smallint NOT NULL,
  start_day smallint NOT NULL,
  notify_days_before smallint NOT NULL DEFAULT 7,
  is_active boolean NOT NULL DEFAULT true,
  ...
);
CREATE TABLE fish_season_push_log (
  user_id uuid REFERENCES users(id),
  calendar_id uuid REFERENCES fish_season_calendar(id),
  season_year smallint NOT NULL,
  UNIQUE (user_id, calendar_id, season_year)
);
```

`notification_settings.season_reminder` (varsa) false ise kullanıcı bu push’ları almaz.

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
│   ├── router.dart              ← go_router; `/home` + `extra: spotId` bildirim deep-link
│   ├── app_routes.dart          ← route path sabitleri (`/map` sabiti var; shell’de ayrı rota yok)
│   ├── go_router_refresh.dart   ← oturum değişiminde yenileme
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
│       ├── score_utils.dart         ← puan hesaplama yardımcıları
│       ├── fishing_score_engine.dart← kural tabanlı balıkçı skoru (saf Dart)
│       ├── moon_phase_calculator.dart← ay + solunar pencereler (İstanbul ref.)
│       ├── fishing_weather_utils.dart← 30 kural özet skoru (legacy)
│       ├── istanbul_ilce_resolver.dart
│       ├── mera_weather_display.dart
│       └── ... (avatar_image_prepare, notification_routing vb.)
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── spot_model.dart
│   │   ├── checkin_model.dart
│   │   ├── fish_log_model.dart
│   │   ├── hourly_weather_model.dart← Open-Meteo saatlik veri (cloudCover dahil)
│   │   ├── fishing_score.dart       ← FishingScoreEngine çıktı modeli
│   │   ├── notification_model.dart
│   │   ├── friend_request_model.dart
│   │   ├── tackle_model.dart
│   │   ├── shop_model.dart
│   │   └── weather_model.dart       ← pressureHpa, pressureHpa3hAgo (Open-Meteo)
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── checkin_repository.dart
│   │   ├── favorite_repository.dart ← spot_favorites CRUD (isFavorited, toggle, getFavoriteSpots, getUsersWhoFavorited)
│   │   ├── fish_log_repository.dart
│   │   ├── follow_repository.dart
│   │   ├── friend_request_repository.dart
│   │   ├── knot_repository.dart
│   │   ├── notification_repository.dart
│   │   ├── shop_repository.dart
│   │   ├── spot_repository.dart
│   │   └── user_repository.dart     ← leaderboard, profil, FCM token güncelleme
│   └── local/
│       ├── database.dart            ← Drift DB init (**schemaVersion 6**)
│       ├── local_spot.dart          ← Drift şema: mera
│       ├── local_fish_log.dart      ← Drift şema: günlük (yerel)
│       ├── local_weather.dart       ← offline hava özeti (basınç yok)
│       ├── sync_queue.dart          ← offline sync kuyruğu (+ retry alanları)
│       └── (generated) database.g.dart
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── onboarding/
│   │       ├── onboarding_screen.dart  ← konum + bildirim akışı (sayfa içi)
│   │       └── step_welcome.dart
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
│   │   ├── leaderboard_screen.dart  ← genel sıra, filtre, “Senin sıran”
│   │   └── rank_screen.dart         ← LeaderboardScreen sarmalayıcısı
│   ├── social/
│   │   ├── social_screen.dart
│   │   ├── friends_list_screen.dart
│   │   └── friend_requests_screen.dart
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
│       ├── settings_screen.dart
│       └── user_spots_list_screen.dart
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
        ├── fishing_score_provider.dart
        ├── follow_provider.dart
        ├── friend_request_provider.dart
        ├── notification_provider.dart
        ├── preferences_provider.dart
        └── user_provider.dart
```

**Not — harita:** `MapScreen` OSM + `flutter_map_cancellable_tile_provider`; kalıcı tile indirme paketi yok (bkz. SPRINT H12).

### assets/fishing (skor motoru)

- `fishing_rules.json` — kural ağırlıkları, hard-stop, mevsim, İstanbul özeli vb.
- `fish_species_istanbul.json` — tür önerileri
- `moon_phase_rules.json` — ay evresi çarpanları

**Fishing Score Engine** yalnızca istemcide çalışır; Edge Function olarak deploy edilmez.

---

## Edge Functions

### weather-cache
- **Tetikleyici:** Cron (her saat başı)
- **Görev:** Saatte bir, son 24 saatte aktif merası olan cache kayıtlarını günceller
- **Dosya:** `supabase/functions/weather-cache/index.ts`

### exif-verify
- **Tetikleyici:** Storage trigger (fotoğraf yüklenince)
- **Görev:** GPS + timestamp doğrula, fish_log kaydını güncelle
- **Not:** Check-in fotoğraf yükleme akışından kaldırıldı; yalnızca balık günlüğü için aktif
- **Dosya:** `supabase/functions/exif-verify/index.ts`
- **⚠️ BİLİNEN HATA:** `supabase/migrations/20240002_exif_storage_trigger.sql` içinde `'Bearer BURAYA_SERVICE_ROLE_KEY_YAZ'` placeholder key bırakılmış. Storage trigger bu haliyle çalışmıyor. Vault/Secret yönetimine taşınmalı.

### score-calculator
- **Tetikleyici:** Flutter istemcisi tarafından HTTP POST ile çağrılır (fire-and-forget, `unawaited`)
- **Görev:** Puan hesapla, users tablosunu güncelle, rütbe kontrol et
- **Dosya:** `supabase/functions/score-calculator/index.ts`
- **⚠️ BİLİNEN GÜVENLİK AÇIĞI:** Fonksiyon gelen request body'deki `user_id` parametresini JWT ile doğrulamadan kullanıyor. Saldırgan başka kullanıcı adına puan kazandırabilir. JWT'den `auth.uid()` okunarak body'deki `user_id` yoksayılmalı.

### nearby-checkin-notifier / morning-weather-push / season-reminder-push
- **Dosyalar:** `supabase/functions/nearby-checkin-notifier`, `morning-weather-push`, `season-reminder-push` — bildirim tetikleme ve zamanlama (cron SQL dosyaları repo kökünde / `supabase/` altında).

### shadow-point-calculator
- **Durum:** ⏳ MVP’de kodlandı olarak işaretlenmiş Edge Function **bu repoda klasör olarak yok**; gölge puan şeması `shadow_points` tablosu ile dokümante. Bildirim entegrasyonu SPRINT H10’da ertelendi.

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

- **Ekran:** `features/map/map_screen.dart` — FlutterMap + OSM tile; `flutter_map_marker_cluster`; `flutter_map_cancellable_tile_provider` ile iptal edilebilir tile istekleri (kalıcı offline tile paketi yok).
- **Veri:** `SpotRepository` Supabase `fishing_spots` okur, başarılı yanıtları Drift `local_spots` tablosuna yazar; ağ hatasında `getCachedSpots()` ile offline fallback.
- **UI:** Pin rengi `privacy_level` (public / friends / private / vip); pin tıklanınca `DraggableScrollableSheet` (inline); sahip için "Düzenle", herkes için "Balık Var!" + "Yol Tarifi".
- **Favori butonu:** `_SpotSheetHeader` (`ConsumerWidget`) — `isFavoritedProvider` ile anlık durum, `bookmark`/`bookmark_border` ikonu; `FavoriteRepository.toggleFavorite` tap'ta çağrılır.
- **Deep-link:** Shell içinde **`/home`** `state.extra` (String `spotId`) ile `MapScreen(initialSpotId: spotId)` açar. `NotificationService` ve bildirim listesi **`AppRoutes.home`** kullanır (`app_routes.dart` içindeki `AppRoutes.map` ayrı shell rotası olarak tanımlı değildir).
- **Giriş noktası:** Onboarding sonrası `/home` → `MainShell` → `MapScreen`.
- **H4 (mera):** `add_spot_screen.dart` (ekle + düzenleme modu), `pick_spot_location_screen.dart`; rotalar: `/map/add-spot`, `/map/edit-spot`, `/map/pick-location`. **Dükkan (`shops`) pin katmanı** → H15.
- **Drift:** `AppDatabase` **schemaVersion 6** — `local_spots`, `local_fish_log`, `fish_logs` (Supabase uyumlu tablo), `local_weather`, `sync_queue`; migrasyon adımları `database.dart` `onUpgrade` içinde.

## Bildirim Sistemi (M-09)

- **FCM + Yerel bildirim:** `notification_service.dart` — ön plan, arka plan ve kapalı durum için 3 ayrı tap akışı.
- **Payload:** Yerel bildirimler artık sadece `type` değil `{"type":"checkin","spot_id":"..."}` şeklinde JSON payload taşır; `_navigateFromPayload` ile decode edilir.
- **Deep-link:** `checkin` / `vote` türündeki bildirimlere tıklanınca `router.go(AppRoutes.home, extra: spotId)` ile `MapScreen` açılır (FCM tap ve bildirim listesi).
- **Bildirim listesi:** `notification_list_screen.dart` — `_navigateForNotification` `notification.data['spot_id']`'yi okur; rank → `/rank`, follow → `/profile`, checkin/vote → `/map` + spotId.
- **Favorileme bildirimi:** Check-in anında `FavoriteRepository.getUsersWhoFavorited(spot.id)` ile favorileyen kullanıcılar bulunur, "Favori Meranızda Balık Var!" bildirimi gönderilir (spot sahibi ve check-in yapan hariç).

## Mera Favorileme

- **DB:** `spot_favorites(user_id PK, spot_id PK, created_at)` — RLS: kendi kayıtları; `spot_id` üzerinde index.
- **Repository:** `FavoriteRepository` — `isFavorited`, `toggleFavorite`, `getFavoriteSpots` (join), `getUsersWhoFavorited`.
- **Provider:** `isFavoritedProvider(spotId)` (FutureProvider.autoDispose.family), `favoriteSpotsProvider` (FutureProvider.autoDispose).
- **Profil:** `_FavoriteSpotsSection` — kendi profili (`isSelf == true`) için favori meralar kart listesi; tap’ta `context.go(AppRoutes.home, extra: spotId)` ile mera açılır.

## Hava Durumu (M-04 / H9)

- **Kaynak:** Open-Meteo (forecast + marine API) — 2 günlük veri (`forecast_days=2`).
- **Saatlik grafik:** Sonraki 24 saat gösterilir; saat başı otomatik güncellenir (kesin saat başı `Timer` ile hesaplanır). Manuel yenileme yok.
- **Metrikler:** `HourlyWeatherModel` — sıcaklık, rüzgar hızı, dalga yüksekliği, deniz yüzey sıcaklığı, akıntı hızı, `cloudCover`. Bulutluluk Open-Meteo `cloudcover` parametresinden çekilir.
- **`WeatherModel`:** `pressureHpa` (anlık yüzey basıncı), `pressureHpa3hAgo` (trend) — Open-Meteo `surface_pressure` / saatlik dizi.
- **Detay grid:** Dalga yüksekliği, deniz yüzey sıcaklığı, akıntı hızı ve bulutluluk `_WeatherDetailGrid`'de `currentHour` verisiyle gösterilir.
- **Balıkçı skoru (istemci):** `FishingScoreEngine` + `fishingScoreProvider`; `weather_screen` “Bugün balık tutulur mu?” kartı `ref.watch(fishingScoreProvider)`; harita `weather_card` aynı provider’ı kullanır. Motor dışı özet için `FishingWeatherUtils` (30 kural) yedek yol olarak kalır.

## Sıralama (Rank)

- **Ekran:** `leaderboard_screen.dart` — `users` tablosundan `getLeaderboard` (RPC `leaderboard_users` veya doğrudan sorgu); isteğe bağlı rütbe filtresi (`leaderboardFilteredProvider`); giriş yapan kullanıcı için global sıra (`my_leaderboard_rank` RPC + yedek sayım).
- **UI:** Açık tema liste; ilk 3 madalya; “Senin sıran” kartı (`AppColors.leaderboardBanner`).
- **Giriş:** `rank_screen.dart` yalnızca `LeaderboardScreen` döndürür; shell rotası `/rank`.

---

## Güvenlik Kuralları

### Zorunlu
- Tüm API istekleri HTTPS (Supabase varsayılan)
- JWT: 1 saat access token, 30 gün refresh token
- Tüm tablolarda RLS aktif, varsayılan DENY *(istisna: `shadow_points` — ⚠️ RLS eksik)*
- Fotoğraflar **public URL** ile servis edilir (`getPublicUrl`) — signed URL kullanılmıyor
- API key ve secret asla client koduna yazılmaz → `.env` dosyası (gitignore'da)

### Bilinen Aktif Güvenlik Açıkları (Mayıs 2026)
| # | Açık | Konum | Aciliyet |
|---|------|-------|----------|
| 1 | `score-calculator` JWT doğrulaması yok | `functions/score-calculator/index.ts` | 🔴 Kritik |
| 2 | `fish-photos` bucket MIME kısıtlaması yok (`NULL`) | `migrations/20260415_storage_fish_photos_bucket.sql` | 🔴 Kritik |
| 3 | `exif-verify` trigger'da hardcoded placeholder key | `migrations/20240002_exif_storage_trigger.sql` | 🔴 Kritik |
| 4 | `shadow_points` tablosunda RLS yok | DB şeması | 🟠 Yüksek |
| 5 | Edge Functions JWT doğrulaması yok (`weather-cache`, `morning-weather-push`) | `functions/` | 🟠 Yüksek |
| 6 | `friends` mera politikası tek yönlü follow'a izin veriyor | `fishing_spots` RLS | 🟡 Orta |

### .gitignore (Eklenmeli)
```
.env
*.env
google-services.json
GoogleService-Info.plist
supabase/.env
```

---

## Tema & Tasarım Sabitleri

> **Not:** Aşağıdaki değerler `lib/app/theme.dart` ile eşleşecek şekilde güncellenmiştir (Mayıs 2026). Önceki versiyonda yer alan bazı renk değerleri (ör. `danger: 0xFFA32D2D`, `background: 0xFFF5F5F3`) gerçek kodla uyumsuzdu.

```dart
// lib/app/theme.dart — DARK-FIRST tema (koyu mod)

class AppColors {
  // Okyanus paleti
  static const navy       = Color(0xFF0A1628); // derin arka plan
  static const teal       = Color(0xFF0D7E8A); // mera pin (public), vurgular
  static const sand       = Color(0xFFC9A84C); // VIP/Deniz Reisi, altın
  static const foam       = Color(0xFFF0F8FF); // açık metin, buton yazısı

  // Semantik renkler
  static const primary    = Color(0xFF0F6E56); // ana buton, FAB
  static const secondary  = Color(0xFF185FA5); // mavi vurgu
  static const accent     = Color(0xFFEF9F27); // amber
  static const background = Color(0xFF07101E); // scaffold arka planı
  static const surface    = Color(0xFF0B1C33); // kart yüzeyi
  static const danger     = Color(0xFFE63946); // hata, silme
  static const success    = Color(0xFF2FBF71); // başarı
  static const muted      = Color(0xFF8EA0B5); // ikincil metin

  // Pin renkleri (privacy_level)
  static const pinPublic  = Color(0xFF0D7E8A); // teal
  static const pinFriends = Color(0xFF185FA5); // secondary blue
  static const pinPrivate = Color(0xFF7B8794); // gri, dikkat çekmez
  static const pinVip     = Color(0xFFC9A84C); // altın

  // Rütbe renkleri
  static const rankAcemi      = Color(0xFF7B8794);
  static const rankOltaKurdu  = Color(0xFF185FA5);
  static const rankUsta       = Color(0xFF0D7E8A);
  static const rankDenizReisi = Color(0xFFC9A84C);
}

// Font ailesi: Poppins (display) — sistem fontuna fallback
class AppTextStyles {
  // 45+ yaş hedef kitle: minimum 16sp gövde, 20sp başlık
  static const h1      = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, fontFamily: 'Poppins');
  static const h2      = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Poppins');
  static const h3      = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins');
  static const body    = TextStyle(fontSize: 16, fontWeight: FontWeight.w500); // min 16sp zorunlu
  static const caption = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
}

// Buton: minimumSize = Size.fromHeight(56) — büyük dokunma alanı
// AppBar: toolbarHeight = 60, titleTextStyle.fontSize = 20
```

---

## Offline Senkronizasyon (SyncQueue)

`SyncService` (`lib/core/services/sync_service.dart`) internet yokken yazma işlemlerini `sync_queue` SQLite tablosuna alır.

- **Tetiklenme:** `connectivity_plus` stream (offline→online anlık) + uygulama açılış kontrolü + 30 sn periyodik poll
- **Sıra:** `createdAt ASC` — ilk gelen ilk işlenir
- **Retry:** Max 5 deneme; 5'te kalıcı hata olarak silinir
- **⚠️ Eksik:** Retry aralarında exponential backoff yok; geçici ağ hatasında 5 deneme hızla tüketilebilir
- **Desteklenen operasyonlar:** `insert`, `update`, `delete`
- **Kapsam:** Yalnızca yazma işlemleri; okumalar Drift cache'ten yapılır

---

## Medya Yükleme ve Sıkıştırma

### İstemci Tarafı Sıkıştırma (`lib/core/utils/avatar_image_prepare.dart`)

Tüm fotoğraflar (balık günlüğü + profil avatarı) yüklenmeden önce `prepareAvatarUploadBytes()` fonksiyonundan geçer:

1. **Katman 1 (native):** `flutter_image_compress` — maks. 1024px, quality 88'den 38'e adım adım azalır
2. **Katman 2 (pure Dart, web fallback):** `image` paketi — 1024→768→512→384→320px basamakları, her biri quality 86'dan 32'ye
3. **Son çare:** 256px @ quality 28
4. **2MB aşılırsa:** Exception fırlatılır, kullanıcı bilgilendirilir

`ImagePicker` ayrıca galeri seçiminde `imageQuality: 85, maxWidth: 1600` uygular (balık günlüğü).

### Storage Bucket Güvenliği

| Bucket | Public | Boyut Limiti | MIME Kısıtlaması |
|--------|--------|--------------|------------------|
| `users-avatars` | ✅ | 2 MB | ✅ jpeg, png, webp |
| `fish-photos` | ✅ | 2 MB | ❌ **NULL — hiç kısıtlama yok** |

> **⚠️ KRİTİK:** `fish-photos` bucket'ında MIME kısıtlaması olmadığından `.sh`, `.exe`, `.html` gibi zararlı dosyalar yüklenebilir. Düzeltme: `UPDATE storage.buckets SET allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp']::text[] WHERE id = 'fish-photos';`

### Öksüz Dosyalar

`FishLogRepository.deleteLog()` DB kaydını siler ancak `fish-photos` Storage nesnesini silmiyor — çöp dosya birikimi oluşur.

---

## Topluluk Moderasyonu (Check-in Oylama)

- **Oylama:** `checkin_votes(checkin_id, voter_id UNIQUE)` — hesap başına tek oy
- **Otomatik gizleme:** `trg_checkin_votes_aggregate` trigger (SECURITY DEFINER): ≥3 oy ve ≥%70 yanlış oyu → `is_hidden = true`
- **RLS:** `checkins SELECT` politikası `is_hidden = false` filtreliyor — gizlenen içerik haritadan anında kayboluyor
- **⚠️ Troll Koruması:** Sahte hesap açma koruması yok; 3 hesap eşiği aşar. Hesap yaşı/rütbe filtresi planlanmamış
- **⚠️ Fotoğraf moderasyonu:** `fish_logs` tablosunda `is_hidden` alanı yok; AI içerik kontrolü yok
- **Admin arayüzü:** Yok; moderasyon manuel Supabase Dashboard'dan yapılıyor

---

## GPS ve Pil Optimizasyonu

- **Mevcut strateji:** Tüm konum sorguları `LocationAccuracy.high` (en yüksek hassasiyet)
- **Check-in doğrulama:** 500 metre yarıçapı (`AppConstants.checkinRadiusMeters`)
- **⚠️ Optimizasyon eksik:** Arama/göz atma senaryolarında da `high` accuracy kullanılıyor — `low` veya `medium` yeterli olur; pil tüketimini azaltır
- **Tile cache:** Yalnızca RAM (`keepBuffer: 8`, `panBuffer: 3`); disk cache veya offline harita yok
- **Cluster:** `maxClusterRadius: 58px`; tüm zoom seviyelerinde aktif (`clusterZoomThreshold = 12.0` sabiti tanımlı ama henüz bağlanmamış)

---

## Bildirim Anti-Spam Kuralları

`notification-sender` Edge Function içinde uygulanan kurallar:

- **Günlük limit:** Kullanıcı başına max 5 push/gün (`force: true` olan bildirimler sayılmaz)
- **Sessiz mod:** 23:00–07:00 İstanbul (push atlanır, in-app kaydedilir)
- **Çift gönderim önleme:** `fish_season_push_log(user_id, calendar_id, season_year) UNIQUE`
- **⚠️ Bilinen hata:** `weather_morning` bildirim tipi `/weather` yerine `/home`'a düşüyor (`_routeForType` switch eksik)
- **⚠️ Bilinen hata:** `morning-weather-push` `.limit(1000)` ile kullanıcı atlıyor; yüksek kullanıcı sayısında tüm kullanıcılara ulaşılamaz
