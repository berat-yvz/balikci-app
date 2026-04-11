# Proje durumu — uygulama özeti (referans)

Bu dosya vekil asistan / geliştirici için **kodla uyumlu anlık özet**tir. Ayrıntılı mimari: [ARCHITECTURE.md](ARCHITECTURE.md). Sprint: [SPRINT.md](SPRINT.md). MVP maddeleri: [MVP_PLAN.md](MVP_PLAN.md).

**Son güncelleme:** H1–H15 tamamlandı ✅; H16 (Launch) ilerliyor — AAB build hazır, Play Store hesabı ve beta kanalı kullanıcıya kalıyor. 325 otomatik test, tümü yeşil.

---

## Yol haritası (özet)

| Öncelik | Modül | Durum | Not |
|--------|--------|--------|-----|
| 1 | M-01 Auth & Onboarding | ✅ | Tamamlandı |
| 2 | M-02 Harita H3–H4 | ✅ | Harita + mera CRUD + favorileme tamamlandı |
| 3 | M-02 H5 Check-in | ✅ | Fotoğraf/EXIF kaldırıldı; sadece yoğunluk+kalabalık seçimi |
| 4 | M-02 H6 EXIF/Oylama | ✅ | Oylama çalışıyor; check-in fotoğrafı kaldırıldı |
| 5 | M-03 H7 Balık Günlüğü | ✅ | Tamamlandı |
| 6 | M-04 H8 Puan & Rütbe | ✅ | Sıralama dikey liste + madalya UI tamamlandı |
| 7 | M-04 H9 Hava Durumu | ✅ | 24s grafik, saat başı güncelleme, deniz metrikleri |
| 8 | M-09 H10 Bildirim | ✅ | Konum bazlı, sessiz mod, günlük limit, sabah hava push — tamamlandı |
| 9 | M-07 H11–H15 | ✅ | Düğüm, sıralama, offline sync, Polish — tamamlandı |
| 10 | H16 Launch | 🔄 | AAB ready; Play Store hesabı + beta kanalı kullanıcıya kalıyor |

---

## Teknoloji

- Flutter, Riverpod, go_router, Drift, Supabase (`supabase_flutter`), Firebase (FCM + `google-services.json`), `flutter_map` + OSM, `flutter_map_marker_cluster`, `flutter_map_tile_caching`, `geolocator`, `app_links` (OAuth dönüşü), `flutter_local_notifications`, Open-Meteo API (forecast + marine).

---

## Giriş ve yönlendirme

- `lib/app/router.dart`: oturum yok → `/login`; onboarding bitmemiş → `/onboarding`; bitmiş → `/home`.
- `/map` rotası `state.extra` (String `spotId`) kabul eder; bildirimden mera deep-link için kullanılır.
- `lib/main.dart`: `.env`, Firebase, Supabase, Drift, `NotificationService` başarısızsa `StartupErrorApp`; OAuth için `AppLinks` + `getSessionFromUrl`; `onAuthStateChange` ile `AuthRepository.ensureUserProfile`.
- Splash: `splash_screen.dart` — kısa gecikme sonra oturum + `SharedPreferences` onboarding bayrağı.

---

## M-01 — Auth ve onboarding (✅)

- E-posta/şifre + Google OAuth.
- Onboarding: konum izni, bildirim izni, hoş geldin adımı.
- Bildirim izni **uygulama açılışında istenmez**; yalnızca onboarding butonu ile istenir.
- Android manifest: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`.

Detay: [M-01_AUTH_ONBOARDING.md](M-01_AUTH_ONBOARDING.md).

---

## M-02 — Harita, Mera & Check-in (✅)

- `/home` → `MainShell` → `MapScreen`.
- `SpotRepository`: Supabase `fishing_spots` CRUD, Drift `local_spots` cache; `getCachedSpots()` offline fallback.
- **Favori buton:** `_SpotSheetHeader` (`ConsumerWidget`) — `isFavoritedProvider` ile durum; `FavoriteRepository.toggleFavorite` çağrısı.
- **Deep-link:** `MapScreen(initialSpotId)` — bildirim tap'ında mera otomatik seçilip bottom sheet açılır.
- Harita: cluster, FMTC tile store, "Balık Var!" + "Yol tarifi" + "Düzenle (sahip)" sheet butonları.
- **Check-in:** Konum doğrulama (±500m), balık yoğunluğu + kalabalık seçimi. Fotoğraf ve EXIF doğrulama **kaldırıldı**.
- **Oylama:** `vote_widget.dart` — doğru/yanlış oy; `vote_dialog.dart`.
- **Favorileme:** `spot_favorites` tablosu + `FavoriteRepository` + `favorite_provider.dart`. Profil sayfasında "Favori Meralarım" bölümü.

---

## M-02 (devam) — Sıralama Sistemi (✅)

- `rank_screen.dart`: Genel / Haftalık / Bölge sekmeleri.
- Tüm sekmeler dikey liste kullanır (podium kaldırıldı).
- Top-3 için 🥇🥈🥉 madalya emoji ve altın/gümüş/bronz zemin rengi.
- **Bug düzeltme:** varsayılan rank `'bronz'` → `'acemi'` düzeltildi.

---

## M-04 — Hava Durumu (✅)

- **API:** Open-Meteo forecast (sıcaklık, rüzgar, yağış, cloudcover) + marine (dalga, SST, akıntı).
- **24 saatlik grafik:** `_next24Hours` ile 24 saatlik veri; saat başında otomatik güncelleme (`_scheduleNextHourlyUpdate`). Manuel yenileme yok.
- **`HourlyWeatherModel`:** `cloudCover` alanı eklendi; `weather_service.dart` `&hourly=...,cloudcover` ile çeker.
- **Detay grid:** Dalga yüksekliği, deniz yüzey sıcaklığı, akıntı hızı, bulutluluk `_WeatherDetailGrid`'de `currentHour` verisiyle.
- **`forecast_days=2`:** Gün sonunda görüntüleme için 2 günlük veri çekilir.

---

## M-09 — Push Bildirim Sistemi (✅)

- FCM ön plan / arka plan / kapalı durum tap akışı.
- **Payload JSON:** `{"type":"checkin","spot_id":"..."}` — `onDidReceiveNotificationResponse` ile decode.
- **Spot deep-link:** Bildirim tap'ında `router.go(AppRoutes.map, extra: spotId)` ile mera açılır.
- **Bildirim listesi:** `_navigateForNotification` `data['spot_id']`'yi okur.
- **Favori mera bildirimi:** `FavoriteRepository.getUsersWhoFavorited` → favorileyen kullanıcılara bildirim.
- **Konum tabanlı bildirim:** `nearby-checkin-notifier` Edge Function — check-in sonrası 2km içindeki aktif kullanıcılara bildirim.
- **Sessiz mod:** `notification-sender`'da 23:00–07:00 push atlanır, in-app kayıt yapılır.
- **Günlük limit:** Günlük 5 bildirim limiti + `force` parametresi (sabah bildirimi sayılmaz).
- **Sabah hava push:** `morning-weather-push` Edge Function + `cron_morning_weather_push.sql` (03:00 UTC).

---

## Supabase DB (üretimde çalışan tablolar)

`users`, `fishing_spots`, `shops`, `checkins`, `checkin_votes`, `fish_logs`, `shadow_points`, `weather_cache`, `notifications`, `follows`, **`spot_favorites`** (migration: `20260409_spot_favorites.sql`).

---

## Önemli dosyalar (hızlı erişim)

| Konu | Dosya |
|------|--------|
| Router | `lib/app/router.dart` |
| OAuth yenileme | `lib/app/go_router_refresh.dart` |
| Ana giriş | `lib/main.dart` |
| Onboarding | `lib/features/auth/onboarding/*.dart` |
| Harita | `lib/features/map/map_screen.dart` |
| Spot veri | `lib/data/repositories/spot_repository.dart` |
| Favori | `lib/data/repositories/favorite_repository.dart` |
| Favori provider | `lib/shared/providers/favorite_provider.dart` |
| Drift | `lib/data/local/database.dart`, `local_spot.dart` |
| Bildirim servisi | `lib/core/services/notification_service.dart` |
| Hava durumu | `lib/features/weather/weather_screen.dart` |
| Sıralama | `lib/features/rank/rank_screen.dart` |
