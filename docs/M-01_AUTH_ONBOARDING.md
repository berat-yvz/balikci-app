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

## `public.users` ve RLS

- Uygulama profil satırını `auth.users.id` ile `public.users.id` üzerinde hizalar.
- **Önerilen sunucu tarafı:** `auth.users` üzerine `AFTER INSERT` tetikleyici — yeni kullanıcı için `public.users` satırı oluşturur (e-posta onayı sonrası oturum gecikse bile tutarlılık). Bkz. [supabase_auth_users_trigger.sql](supabase_auth_users_trigger.sql).
- İstemci tarafında `ensureUserProfile` eski/kısmi hesaplar için **yedek** upsert benzeri davranış sağlar.
- **RLS:** [supabase_rls_users_policies.sql](supabase_rls_users_policies.sql) — kendi satırını güncelleme; herkese açık profil okuma (liderlik için). Tetikleyici `SECURITY DEFINER` ile insert yapar.

## Google OAuth (Flutter)

- `AuthRepository.signInWithGoogle()` → `signInWithOAuth(OAuthProvider.google, redirectTo: ...)`.
- **Android:** `AndroidManifest.xml` içinde `balikciapp` şeması için `VIEW` intent-filter.
- **iOS:** `Info.plist` içinde `CFBundleURLTypes` ile aynı şema.
- Dönüş URI’si için `app_links` ile dinleme; `getSessionFromUrl` ile oturum tamamlanır.

## E-posta onayı (Supabase ayarı)

E-posta onayı açıksa `signUp` sonrası oturum hemen oluşmayabilir. Kullanıcıya “E-postanızdaki bağlantıya tıklayın, ardından giriş yapın” mesajı gösterilir ([register_screen.dart](../lib/features/auth/register_screen.dart)).

## Manuel test listesi (M-01)

1. `.env` + `google-services.json` varken uygulama açılır; splash → login.
2. Kayıt → (onay kapalıysa) onboarding → home.
3. Giriş → onboarding bitmişse home.
4. Çıkış (ileride ayarlardan) → login.
5. Google ile giriş → tarayıcı/hesap seçici → uygulamaya dönüş → profil satırı var.
6. E-posta onayı açıkken kayıt → bilgilendirme ve login yönlendirmesi.
