# Proje durumu — uygulama özeti (referans)

Bu dosya vekil asistan / geliştirici için **kodla uyumlu anlık özet**tir. Ayrıntılı mimari: [ARCHITECTURE.md](ARCHITECTURE.md). Sprint: [SPRINT.md](SPRINT.md). MVP maddeleri: [MVP_PLAN.md](MVP_PLAN.md).

**Son güncelleme:** H1–H5 tamamlandı ✅; H6 (EXIF/Oylama) kısmen tamamlandı — Storage trigger, %70 yanlış oy gizleme ve rozet UI eksik. Sıradaki odak: H6 kalan → H7 Balık Günlüğü.

---

## Yol haritası (özet)

| Öncelik | Modül | Durum | Not |
|--------|--------|--------|-----|
| 1 | M-01 Auth & Onboarding | ✅ | Tamamlandı; `public.users` tetikleyici + RLS production’da doğrulanacak |
| 2 | M-02 Harita H3–H4 | ✅ | Harita temeli + mera CRUD tamamlandı; dükkan pinleri H15’e ertelendi |
| 3 | M-02 H5 Check-in | ✅ | Check-in + Realtime + konum doğrulama tamamlandı |
| 4 | M-02 **H6 EXIF/Oylama** | 🔄 | exif_helper + vote_widget tamam; **kalan:** Storage trigger, %70 yanlış gizleme, rozet UI |
| 5 | M-03 H7 Balık Günlüğü | ⏳ | Sıradaki sprint |
| 6 | M-03+ H8–H16 | ⏳ | MVP_PLAN sırası |

---

## Teknoloji

- Flutter, Riverpod, go_router, Drift, Supabase (`supabase_flutter`), Firebase (FCM + `google-services.json`), `flutter_map` + OSM, `flutter_map_marker_cluster`, `flutter_map_tile_caching`, `geolocator`, `app_links` (OAuth dönüşü).

---

## Giriş ve yönlendirme

- `lib/app/router.dart`: oturum yok → `/login`; onboarding bitmemiş → `/onboarding`; bitmiş → `/home`.
- `lib/main.dart`: `.env`, Firebase, Supabase, Drift, `NotificationService` başarısızsa `StartupErrorApp`; OAuth için `AppLinks` + `getSessionFromUrl`; `onAuthStateChange` ile `AuthRepository.ensureUserProfile`.
- Splash: `splash_screen.dart` — kısa gecikme sonra oturum + `SharedPreferences` onboarding bayrağı.

---

## M-01 — Auth ve onboarding

- E-posta/şifre + Google OAuth (`AuthRepository`, `oauth_constants.dart` — `balikciapp://login-callback/`).
- Onboarding tamamı: `preferences_provider` / `SharedPreferences` (`isOnboardingCompleted` benzeri bayrak).
- **İzin adımları:**
  - Bildirim izni **uygulama açılışında istenmez** (`NotificationService.initialize` içinde `requestPermission` yok).
  - İzin, yalnızca onboarding’de ilgili butonla istenir.
  - **Sayfa geçişi:** izin verildikten sonra **otomatik ilerleme yok**; kullanıcı alttaki **İleri** ile geçer (izin isteğe bağlı; **Atla** tüm onboarding’i atlar).
- **Konum adımı** (`step_location.dart`): `AutomaticKeepAliveClientMixin` + `WidgetsBindingObserver`; OS izin durumu (`checkPermission`) ve `resumed` ile senkron; izin verilmişse buton kalıcı kapalı + “Konum izni verildi”. **Başarılı izin sonrası altta yeşil SnackBar gösterilmez** (red / kalıcı red için uyarılar durur).
- **Bildirim adımı** (`step_notification.dart`): aynı mixin’ler; `getNotificationSettings` ile OS senkronu; izin verilmişse buton kapalı + “Bildirim izni verildi”. **Başarılı izin sonrası altta yeşil SnackBar gösterilmez**; reddedilirse **İleri** ile devam, geri dönülürse tekrar denenebilir.
- **Android manifest:** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS` (13+), OAuth `intent-filter` (`balikciapp` / `login-callback`).
- **iOS:** Konum usage string’leri + `CFBundleURLTypes` OAuth şeması (bkz. `ios/Runner/Info.plist`).

Detay: [M-01_AUTH_ONBOARDING.md](M-01_AUTH_ONBOARDING.md).

---

## M-02 — Harita & Check-in (H3–H5 tamamlandı, H6 devam ediyor)

- `/home` → `MainShell` → doğrudan `MapScreen` (placeholder yok).
- `SpotRepository`: Supabase `fishing_spots` listeleme/sayfalama, bbox sorgusu, CRUD + Drift `local_spots` upsert; `getCachedSpots()` offline fallback.
- Drift: `AppDatabase` **schemaVersion 2** — `local_spots` alanları (`verified`, `muhtarId`, `cachedAt`); migrasyon `database.dart` içinde.
- Harita: cluster, FMTC tile store, `SpotDetailSheet` salt okunur + **Yol tarifi** (`geo` / Google Maps).
- **H4 (mera):** `add_spot_screen` (ekle + sahip için güncelle), `pick_spot_location_screen`, `/map/add-spot`, `/map/edit-spot`, `/map/pick-location`; detay sheet **Düzenle**; haritada FAB **Mera ekle**. **Dükkan (`shops`) pinleri** FAZ E H15’e ertelendi.
- **Harita UI entegrasyonu:** `MapScreen` üzerinde hızlı aksiyonlar (**Konumum**, **Mera ekle**), sheet içinde **Check-in / Yol tarifi / Düzenle** butonları ve arama alanında **Bildirim** kısayolu.
- `/map` rotası hâlâ tanımlı; ana giriş yolu `/home` → `MainShell` → `MapScreen`.

### H5 — Check-in (tamamlandı)

- `checkin_screen.dart`: konum doğrulama (± 500m), balık yoğunluğu + kalabalık seçimi (4 seviye).
- `checkin_repository.dart`: Supabase insert + Realtime subscription.
- Harita pin'i anlık güncelleniyor; 2 saat sonra opacity azalır.

### H6 — EXIF & Oylama (devam ediyor)

- `exif_helper.dart`: native_exif ile GPS + timestamp okuma (tamam).
- `exif-verify` Edge Function yazıldı (tamam), deploy + storage trigger **kurulacak**.
- `vote_widget.dart` + `checkin_repository` vote fonksiyonu (tamam).
- **Kalan:** Storage trigger, %70+ yanlış oy → check-in gizleme mantığı, doğrulanmış check-in rozeti UI.

---

## Sunucu tarafı (doğrulama bekleyen)

- Production SQL: şema `supabase_schema.sql`; tetikleyici + `users`/`fishing_spots` RLS `supabase_fix_mera_insert.sql`; diğer tablolar `supabase_rls_app_tables.sql`.

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
| Drift | `lib/data/local/database.dart`, `local_spot.dart` |
| Bildirim | `lib/core/services/notification_service.dart` |
