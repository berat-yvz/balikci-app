# M-01 — Hesap girişi ve onboarding (teknik rehber)

Bu dosya [MVP_PLAN.md](MVP_PLAN.md) M-01 maddesi ile **gerçek kod akışını** eşleştirir. Uygulama: Flutter + Riverpod + go_router + Supabase Auth (e-posta/şifre + Google OAuth) + Firebase FCM (bildirim izni adımı).

## Route özeti (go_router)

| Durum | Davranış |
|--------|----------|
| Oturum yok | Korumalı rotalara gidilince `/login` |
| Oturum var, onboarding bitmedi | `/onboarding` |
| Oturum var, onboarding bitti | `/home` |
| Splash `/splash` | ~2 sn sonra oturum + onboarding bayrağına göre yönlendirme |

**Dosyalar:**

- [lib/app/router.dart](../lib/app/router.dart) — `redirect` kuralları
- [lib/features/auth/splash_screen.dart](../lib/features/auth/splash_screen.dart)
- [lib/features/auth/login_screen.dart](../lib/features/auth/login_screen.dart)
- [lib/features/auth/register_screen.dart](../lib/features/auth/register_screen.dart)
- Onboarding: [lib/features/auth/onboarding/onboarding_screen.dart](../lib/features/auth/onboarding/onboarding_screen.dart), `step_location.dart`, `step_notification.dart`, `step_first_spot.dart`
- Onboarding tamamlanma bayrağı: [lib/shared/providers/preferences_provider.dart](../lib/shared/providers/preferences_provider.dart) (`SharedPreferences`)

**MVP_PLAN’daki dosya isimleri** (`onboarding_step1.dart` vb.) ile kodda kullanılan `step_*.dart` dosyaları aynı adımları temsil eder.

## Oturum yönetimi

- **Şu an:** `supabase_flutter` oturumu (access/refresh token) SDK tarafından saklanır; router yenilemesi `auth.onAuthStateChange` ile tetiklenir.
- **Gelecek (isteğe bağlı):** Hassas yedekleme için `flutter_secure_storage` veya ek policy dokümante edilebilir. MVP metnindeki “JWT Drift’te” ifadesi bu repo sürümünde **uygulanmıyor**; Drift harita/günlük offline için kullanılacak.

## Yerel geliştirme önkoşulları

1. **`.env`** (proje kökü, `pubspec.yaml` içinde asset olarak listelenmeli):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
2. **Android FCM:** `android/app/google-services.json` (Firebase Console).
3. **Google OAuth (mobil):**
   - Supabase Dashboard → Authentication → Providers → Google: etkin, Client ID / Secret.
   - **Redirect URL** (Supabase): uygulama şeması ile eşleşmeli, örn. `balikciapp://login-callback/` (kod ile aynı olmalı).
   - Android: Google Cloud’da OAuth istemcisi, gerekirse **SHA-1** (debug keystore) ekleme.
4. Uygulama başlangıcında `.env` veya Firebase eksikse [lib/main.dart](../lib/main.dart) içinde hata yakalanıp **Başlatma Hatası** ekranı gösterilir (login gelmez; önce yapılandırmayı tamamlayın).
5. **Onboarding konum adımı:** Android’de `AndroidManifest.xml` içinde `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` tanımlı olmalı; iOS’ta `Info.plist` içinde `NSLocationWhenInUseUsageDescription` (ve gerekirse `NSLocationAlwaysAndWhenInUseUsageDescription`) olmalı — aksi halde izin diyaloğu çıkmaz.
6. **Onboarding bildirim adımı (Android 13+):** `POST_NOTIFICATIONS` izninin manifest’te tanımlı olması gerekir; aksi halde `FirebaseMessaging.requestPermission` sistem diyaloğunu göstermeyebilir.

## `public.users` ve RLS

- Uygulama profil satırını `auth.users.id` ile `public.users.id` üzerinde hizalar.
- **Önerilen sunucu tarafı:** `auth.users` üzerine `AFTER INSERT` tetikleyici — yeni kullanıcı için `public.users` satırı oluşturur (e-posta onayı sonrası oturum gecikse bile tutarlılık). Bkz. [supabase_fix_mera_insert.sql](supabase_fix_mera_insert.sql) (bölüm 1–2: tetikleyici + `users` RLS).
- İstemci tarafında `ensureUserProfile` eski/kısmi hesaplar için **yedek** upsert benzeri davranış sağlar.
- **Ek tablo RLS** (checkins, shops, …): [supabase_rls_app_tables.sql](supabase_rls_app_tables.sql). Profil okuma/güncelleme ile çakışmıyorsa aynı projede birlikte kullanılır.

## Google OAuth (Flutter)

- `AuthRepository.signInWithGoogle()` → `signInWithOAuth(OAuthProvider.google, redirectTo: ...)`.
- **Android:** `AndroidManifest.xml` içinde `balikciapp` şeması için `VIEW` intent-filter.
- **iOS:** `Info.plist` içinde `CFBundleURLTypes` ile aynı şema.
- Dönüş URI’si için `app_links` ile dinleme; `getSessionFromUrl` ile oturum tamamlanır.

## E-posta onayı (Supabase ayarı)

E-posta onayı açıksa `signUp` sonrası oturum hemen oluşmayabilir. Kullanıcıya “E-postanızdaki bağlantıya tıklayın, ardından giriş yapın” mesajı gösterilir ([register_screen.dart](../lib/features/auth/register_screen.dart)).

## Onboarding izin akışı (konum + bildirim)

1. **Konum adımı (`step_location.dart`):**
   - Cihazda konum servisi kapalıysa kullanıcıya uyarı dialogu gösterilir ve ayarlara yönlendirme sunulur.
   - İzin `denied` ise sistem izni yeniden istenir.
   - İzin `deniedForever` ise uygulama ayarlarına yönlendirme sunulur.
   - İzin verildiğinde sayfa otomatik değişmez; kullanıcı alttaki **İleri** ile sonraki adıma geçer.
   - İzin **başarıyla verildiğinde** altta yeşil SnackBar gösterilmez; geri bildirim butonun pasif olması ve **“Konum izni verildi”** metniyle verilir.
2. **Bildirim adımı (`step_notification.dart`):**
   - Bildirim izni uygulama açılışında otomatik istenmez.
   - İzin yalnızca kullanıcı **Bildirimlere İzin Ver** butonuna bastığında istenir.
   - İzin verildikten sonra `NotificationService.syncFcmToken()` çağrılır ve `users.fcm_token` güncellenir.
   - İzin reddedilse bile akış kilitlenmez; sonraki adım yine **İleri** ile alınır (izin isteğe bağlıdır).

**Teknik notlar (izin adımları):**

- `NotificationService.initialize()` uygulama açılışında **bildirim izni istemez**; yalnızca izin zaten verilmişse `getNotificationSettings` + `syncFcmToken` çalışır.
- `step_location` / `step_notification`: `AutomaticKeepAliveClientMixin` (`wantKeepAlive: true`) — PageView’de ileri/geri kaydırınca adım state’i korunur.
- `WidgetsBindingObserver` + `didChangeAppLifecycleState(resumed)` — kullanıcı ayarlardan döndüğünde OS izin durumu yeniden okunur; izin verildiyse ilgili buton kapalı kalır.
- `ScaffoldMessenger.maybeOf` — snackbar gösteriminde güvenli erişim.

## Manuel test listesi (M-01)

1. `.env` + `google-services.json` varken uygulama açılır; splash → login.
2. Kayıt → (onay kapalıysa) onboarding → home.
3. Giriş → onboarding bitmişse home.
4. Çıkış (ileride ayarlardan) → login.
5. Google ile giriş → tarayıcı/hesap seçici → uygulamaya dönüş → profil satırı var.
6. E-posta onayı açıkken kayıt → bilgilendirme ve login yönlendirmesi.
7. Onboarding konum adımı: service kapalı/denied/deniedForever senaryolarında doğru dialog ve yönlendirme çalışır.
8. Bildirim izni yalnızca onboarding bildirim adımında, butona basılınca istenir (app açılışında istenmez).
9. Bildirim izni verildiğinde `users.fcm_token` yazılır; izin reddinde de **İleri** ile devam edilebilir.
10. Konum/bildirim adımlarında izin sonrası otomatik sayfa geçişi yoktur; **İleri** beklenir.
11. Onboarding’de sayfa 0→1→0 kaydırınca konum izni verilmişse “Konum İznini Ver” yine kapalıdır.
12. Bildirim izni verilmişse sayfalar arasında gidip gelince bildirim butonu kapalı kalır; reddedildiyse tekrar açılabilir.
13. Konum izni başarılı olduğunda ekranın altında yeşil “izin verildi” SnackBar çıkmaz.

## İlgili özet

Tüm modül özeti: [PROJECT_STATUS.md](PROJECT_STATUS.md).
