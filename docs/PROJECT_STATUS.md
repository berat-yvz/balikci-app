# Proje durumu — uygulama özeti (referans)

Bu dosya vekil asistan / geliştirici için **kodla uyumlu anlık özet**tir. Ayrıntılı mimari: [ARCHITECTURE.md](ARCHITECTURE.md). Sprint: [SPRINT.md](SPRINT.md). MVP maddeleri: [MVP_PLAN.md](MVP_PLAN.md).

**Son güncelleme:** 12 Nisan 2026 — Drift `schemaVersion` **6**; otomatik test **344**, tamamı yeşil (`flutter test`).

---

## Yol haritası (özet)

| Öncelik | Modül | Durum | Not |
|--------|--------|--------|-----|
| 1 | M-01 Auth & Onboarding | ✅ | E-posta/şifre + Google OAuth; onboarding `onboarding_screen.dart` + `step_welcome.dart` (sayfa içi konum/bildirim adımları) |
| 2 | M-02 Harita H3–H4 | ✅ | Harita `/home` → `MapScreen`; mera CRUD; `flutter_map_cancellable_tile_provider`; cluster; dükkan pinleri (`ShopRepository`) |
| 3 | M-02 H5 Check-in | ✅ | ±500 m, yoğunluk/kalabalık, `fish_species[]`; fotoğraf/EXIF check-in’de yok |
| 4 | M-02 H6 Oylama | ✅ | `VoteWidget` / `vote_dialog`; ≥3 oy ve ≥%70 yanlış → `isSuppressedByVotes`; gizleme sonrası `ScoreService.wrongReport` → `score-calculator` |
| 5 | M-03 H7 Balık Günlüğü | ✅ | `add_log_screen`, `log_list_screen`, `stats_screen`; Drift `FishLogs` + `local_fish_log`; Storage `fish-photos` |
| 6 | M-04 H8 Puan & Rütbe | ✅ | `rank_screen.dart` → `LeaderboardScreen`; Supabase `users`; `leaderboardFilteredProvider`, `myLeaderboardRankProvider`; RPC `my_leaderboard_rank` (migration repo’da) |
| 7 | M-04 H9 Hava Durumu | ✅ | Open-Meteo forecast + marine; `WeatherModel.pressureHpa` / `pressureHpa3hAgo`; 24 saat grafik; saat başı yenileme |
| 7b | H9-EXT Fishing Score | ✅ | Saf Dart `FishingScoreEngine` + asset JSON; `fishingScoreProvider` + `weather_screen` / `weather_card` kartı |
| 8 | M-09 H10 Bildirim | ✅ | FCM token → `users.fcm_token`; deep-link `AppRoutes.home` + `extra: spotId`; limit, sessiz saat, yakın check-in, sabah hava, sezon, `rank_up` |
| 9 | M-07 H11–H15 | 🔄 | Düğüm rehberi ✅; offline harita indirme ⏳ (paket yok); Polish çoğunlukla ✅ |
| 10 | H16 Launch | 🔄 | AAB / imzalama hazırlığı kodda; mağaza adımları kullanıcıya kalıyor |

---

## Teknoloji (pubspec ile uyumlu)

- Flutter, **Riverpod 2.x**, **go_router**, **Drift** + `drift_flutter`, **Supabase** (`supabase_flutter`), **Firebase** (FCM), **`flutter_map`** + OSM, **`flutter_map_marker_cluster`**, **`flutter_map_cancellable_tile_provider`**, `geolocator`, `app_links`, `flutter_local_notifications`, `connectivity_plus`, `image_picker` / sıkıştırma, `native_exif`.
- **Hava:** Open-Meteo (forecast + marine); özet metin için ayrıca `FishingWeatherUtils` (30 kural) ve **`FishingScoreEngine`** (JSON kuralları).
- **Not:** `flutter_map_tile_caching` **pubspec’te yok**; kalıcı offline tile indirme henüz bağlanmadı ([SPRINT.md](SPRINT.md) H12).
- **HTTP:** Ağ çağrıları çoğunlukla `supabase_flutter` ve `weather_service` içi `http` / URL; ayrı **`dio` paketi yok** (ARCHITECTURE eski satırları güncellendi).

---

## Giriş ve yönlendirme

- `lib/app/router.dart`: oturum yok → `/login`; onboarding bitmemiş → `/onboarding`; bitmiş → `/home`.
- **Harita girişi:** `AppRoutes.home` → `MainShell` → `MapScreen`. `AppRoutes.map` sabiti `app_routes.dart` içinde tanımlıdır; **go_router’da ayrı `/map` rotası yok** — bildirim ve deep-link **`router.go(AppRoutes.home, extra: spotId)`** kullanır.
- `lib/main.dart`: `.env`, Firebase, Supabase, Drift, `NotificationService`; OAuth için `AppLinks`; `onAuthStateChange` ile profil senkronu.
- `lib/app/go_router_refresh.dart`: oturum değişiminde router yenileme.

---

## M-01 — Auth ve onboarding (✅)

- E-posta/şifre + Google OAuth.
- Onboarding: **tek ekran** (`onboarding_screen.dart`) içinde sayfalı akış + `step_welcome.dart`; konum ve bildirim izinleri bu yapı içinde (ayrı `step_location.dart` / `step_first_spot.dart` dosyaları **yok**).
- Bildirim izni uygulama açılışında değil; onboarding içinde kullanıcı aksiyonu ile.
- Android: konum + `POST_NOTIFICATIONS`.

Detay: [M-01_AUTH_ONBOARDING.md](M-01_AUTH_ONBOARDING.md) (varsa genel akışla çelişirse önce koda güvenin).

---

## M-02 — Harita, Mera & Check-in (✅)

- `SpotRepository`: `fishing_spots` + Drift `local_spots`.
- Favori: `spot_favorites`, `FavoriteRepository`, profil bölümü.
- Check-in: `checkin_screen.dart`, Realtime, `CheckinRepository`.
- Oylama: `vote_widget.dart`, `vote_dialog.dart`.

---

## Sıralama (✅)

- `lib/features/rank/rank_screen.dart` → `LeaderboardScreen` (`leaderboard_screen.dart`).
- Supabase `users`; `getLeaderboard` + isteğe bağlı `rankFilter`; `my_leaderboard_rank` RPC (Supabase migration dosyası: `supabase/migrations/20260416300000_my_leaderboard_rank.sql`).
- **Not:** Haftalık/bölge sekmeli eski `RankScreen` yapısı kaldırıldı; genel liste + rütbe filtresi + “Senin sıran” kartı.

---

## M-04 — Hava & balıkçı skoru (✅)

- Open-Meteo; `WeatherModel` içinde **`pressureHpa`**, **`pressureHpa3hAgo`** (trend).
- Drift **`local_weather`**: `regionKey`, sıcaklık, rüzgar, dalga, nem, `cachedAt` — **basınç kolonu yerelde yok**; basınç tam metin/API modelinde.
- **`FishingScoreEngine`** (`lib/core/utils/fishing_score_engine.dart`): `assets/fishing/*.json` + `MoonPhaseCalculator` (solunar, İstanbul yaklaşık koordinat); `fishingScoreProvider` → `weather_screen` “Bugün balık tutulur mu?” kartı ve harita `weather_card`.
- Hata/legacy yol: `FishingWeatherUtils.getFishingScore` ile basit skor.

---

## M-09 — Push (✅)

- `NotificationService`: token `UserRepository.updateFcmToken`, yenileme dinleyicisi, onboarding/ayarlardan `syncFcmToken`.
- Payload JSON; spot için `AppRoutes.home` + `extra`.

---

## Supabase (repo ile hizalı tablolar)

`users`, `fishing_spots`, `shops`, `checkins`, `checkin_votes`, `fish_logs`, `shadow_points`, `weather_cache`, `notifications`, `follows`, `spot_favorites`; sezon için `fish_season_calendar` / `fish_season_push_log` (migration dosyalarına bakın).

---

## Drift (`lib/data/local/database.dart`)

- **`schemaVersion`: 6**
- Tablolar: `LocalSpots`, `LocalFishLogs`, **`FishLogs`** (H7 senkron), `SyncQueue` (retry alanları), **`LocalWeather`**
- Migrasyon zinciri: v1→v2 `local_spots` kolonları; v3 `local_weather`; v4 `sync_queue` kolonları; v5 `local_fish_log` kolonları; v6 `fishLogs` tablosu

---

## Edge Functions (repo: `supabase/functions/`)

`weather-cache`, `exif-verify`, `score-calculator`, `notification-sender`, `nearby-checkin-notifier`, `morning-weather-push`, `season-reminder-push`.

**İstemci tarafı:** Balıkçılık skoru **Edge Function değil** — `FishingScoreEngine` uygulama içi.

---

## Önemli dosyalar (hızlı erişim)

| Konu | Dosya |
|------|--------|
| Router | `lib/app/router.dart` |
| Route sabitleri | `lib/app/app_routes.dart` |
| OAuth / refresh | `lib/app/go_router_refresh.dart` |
| Ana giriş | `lib/main.dart` |
| Ana kabuk / 5 sekme | `lib/features/main_shell.dart` |
| Onboarding | `lib/features/auth/onboarding/onboarding_screen.dart`, `step_welcome.dart` |
| Harita | `lib/features/map/map_screen.dart` |
| Sıralama | `lib/features/rank/leaderboard_screen.dart`, `rank_screen.dart` |
| Hava | `lib/features/weather/weather_screen.dart`, `providers/istanbul_weather_provider.dart` |
| Fishing score | `lib/core/utils/fishing_score_engine.dart`, `moon_phase_calculator.dart`, `lib/shared/providers/fishing_score_provider.dart`, `lib/data/models/fishing_score.dart`, `assets/fishing/*.json` |
| Balık günlüğü | `lib/features/fish_log/screens/add_log_screen.dart`, `log_list_screen.dart`, `stats_screen.dart` |
| Kullanıcı / liderlik | `lib/data/repositories/user_repository.dart`, `lib/shared/providers/user_provider.dart` |
| Drift | `lib/data/local/database.dart`, `local_spot.dart`, `local_fish_log.dart`, `local_weather.dart`, `sync_queue.dart` |
| Bildirim | `lib/core/services/notification_service.dart` |
| Sosyal | `lib/features/social/social_screen.dart`, `friends_list_screen.dart`, `friend_requests_screen.dart` |
