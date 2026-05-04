# Balıkçı Super App — Proje Devir Teslim Rehberi

> **Hedef:** Bu projeye sıfırdan dahil olan bir Senior Flutter/Supabase geliştiricisinin ilk haftasını verimli geçirmesini sağlamak.  
> **Son Güncelleme:** Mayıs 2026 — Tüm analizler (`GAMIFICATION_ANALYSIS.md`, `NOTIFICATION_ANALYSIS.md`, `SECURITY_ANALYSIS.md`, `LOCATION_BATTERY_ANALYSIS.md`) ile uyumlu.

---

## 1. Proje Özeti ve Felsefesi

### 1.1 Uygulama Nedir?

**Balıkçım**, Türkiye'deki amatör ve profesyonel balıkçılar için geliştirilmiş bir **"Super App"** — tek uygulamada harita, gerçek zamanlı check-in, hava durumu, balık günlüğü ve sosyal katman. Play Store adı: **Balıkçım**.

**Çözdüğü problemler:**
- Balıkçılar gizli meraları "ağızdan kulağa" öğrenir — uygulama bunu güvenli ve kademeli biçimde sayısallaştırıyor.
- "Bugün nereye gideyim?" sorusu için gerçek zamanlı check-in verisi + AI-destekli hava balıkçılık skoru sunuyor.
- Gün batımında avlanan türler, sezon takvimleri ve düğüm rehberi tek ekranda.

### 1.2 Hedef Kitle Kuralı — En Kritik Tasarım Kısıtı

**45+ yaş, düşük dijital okuryazarlığa sahip balıkçı amcalar.**

Bu kural projenin her katmanını etkiler:

| Etki Alanı | Kural |
|-----------|-------|
| **UI Font** | Minimum 16sp gövde, 20sp+ başlık |
| **İkonlar** | Emoji + metin birlikte (sadece ikon yeterli değil) |
| **Hata Mesajları** | Teknik terim yok; "Bağlantı kesildi, lütfen tekrar dene" |
| **Akış Karmaşıklığı** | Maks. 3 adım, geri dönüş her zaman açık |
| **Kodlama** | Sessiz başarısızlık (fail silently): ağ hatası check-in akışını durdurmamalı |
| **Terminoloji** | "Check-in" → "Buraya Geldim", "Rank" → "Rütbe", "VIP" → "Usta Merası" |

---

## 2. Mimari ve Teknoloji Yığını

### 2.1 Tech Stack Özeti

```
Flutter 3.x (Dart 3.11+)
├── State:       Riverpod 2.x (AsyncNotifier / StreamProvider / Provider)
├── Navigation:  go_router 14.x (ShellRoute + nested routes)
├── Local DB:    Drift 2.x (SQLite — offline cache)
├── HTTP:        Supabase Flutter SDK 2.x
└── Map:         flutter_map 7.x + flutter_map_marker_cluster

Supabase (Backend-as-a-Service)
├── DB:          PostgreSQL + RLS (Row Level Security)
├── Functions:   Edge Functions (Deno / TypeScript)
├── Auth:        Supabase Auth (email/password + PKCE flow)
├── Storage:     fish-photos, users-avatars (2MB limit)
├── Realtime:    Postgres Changes (checkins tablosu)
└── Cron:        pg_cron + pg_net → Edge Function tetikleme

Firebase
└── FCM:         Push notification token yönetimi

Dış Servisler
├── Open-Meteo:  Ücretsiz hava/deniz API (istemci DOĞRUDAN çağırmaz)
└── ArcGIS:      Tile provider (uydu + sınırlar katmanı)
```

### 2.2 Klasör Yapısı (Feature-First Mimari)

```
lib/
├── main.dart                    # Uygulama başlangıç noktası
├── app/
│   ├── router.dart              # go_router konfigürasyonu
│   ├── app_routes.dart          # Tüm route path sabitleri (AppRoutes.xxx)
│   └── theme.dart               # AppColors, AppTextStyles, buildAppTheme()
│
├── core/
│   ├── constants/               # AppConstants, WeatherRegions vb.
│   ├── services/                # Singleton servisler (LocationService, WeatherService,
│   │                            #   NotificationService, ScoreService, SyncService)
│   ├── utils/                   # GeoUtils, ScoreUtils, NotificationRouting vb.
│   └── widgets/                 # SplashScreen, paylaşılan widget'lar
│
├── data/
│   ├── local/                   # Drift tabloları: LocalSpots, FishLogs, SyncQueue, LocalWeather
│   ├── models/                  # SpotModel, UserModel, CheckinModel, WeatherModel vb.
│   └── repositories/            # Her tablo için repository (SpotRepository, UserRepository…)
│
├── features/
│   ├── auth/                    # Login, Register, Onboarding, ResetPassword
│   ├── map/                     # MapScreen (ana ekran), AddSpotScreen, widget'lar
│   ├── checkin/                 # CheckinScreen
│   ├── fish_log/                # LogListScreen, AddLogScreen, StatsScreen
│   ├── balikcim/                # BalikcimScreen + daily_forecast + fish_encyclopedia
│   ├── weather/                 # WeatherScreen + providers
│   ├── social/                  # SocialScreen, FriendsList, FriendRequests
│   ├── notifications/           # NotificationListScreen, NotificationSettingsScreen
│   ├── profile/                 # ProfileScreen, SettingsScreen
│   ├── rank/                    # (go_router'da /rank → /social redirect)
│   └── knots/                   # Düğüm rehberi
│
└── shared/
    └── providers/               # auth_provider, notification_provider,
                                 #   favorite_provider, connectivity_provider,
                                 #   preferences_provider
```

### 2.3 Katman İletişim Kuralları

```
Widget (UI)
  └─► ref.watch(provider)           # Riverpod ile state okuma
        └─► Repository              # Supabase sorguları veya Drift
              └─► SupabaseService / AppDatabase.instance
                    └─► Supabase Cloud / SQLite

Edge Function çağrısı:
Widget → ScoreService.award() → SupabaseService.client.functions.invoke()
                                    → score-calculator Edge Function → DB UPDATE
```

**Kural:** Widget asla doğrudan `SupabaseService.client` çağırmamalı. Tüm veri erişimi Repository üzerinden geçmeli.

---

## 3. Sistemin Kalp Mekanizmaları

### 3.1 Hava Durumu Pipeline'ı

```
[pg_cron: her saat başı]
    └→ weather-cache Edge Function (Deno/TS)
         └→ Open-Meteo Forecast API (12 kıyı bölgesi)
         └→ Open-Meteo Marine API (isteğe bağlı)
         └→ 39 İstanbul ilçe merkezi için aynı çağrı
         └→ weather_cache tablosuna UPSERT (region_key unique)

[Flutter İstemci]
    └→ WeatherService.fetchRegionalWeatherFromSupabase(regionKey)
         └→ weather_cache tablosu → WeatherModel
         └→ IstanbulIlceResolver ile en yakın ilçe tespiti
         └→ HourlyWeatherModel listesi (48 saatlik tahmin)

[Balıkçılık Skoru]
    fishing_summary: fishingSummaryWmo(temp, wind, wmoCode)
    → "Bugün hava tam lüfer havası ✓" gibi metinler
    → weather-cache Edge Function içinde hesaplanıp DB'ye yazılır
```

**Önemli:** İstemci **hiçbir zaman** doğrudan Open-Meteo'ya istek atmaz. Tüm hava verisi `weather_cache` tablosundan okunur.

### 3.2 Oyunlaştırma ve Puan Ekonomisi

**Puan kaynakları** (`ScoreUtils` + `score-calculator` Edge Function):

| Eylem | Puan | Durum |
|-------|------|-------|
| Mera paylaşımı (public) | +50 | ✅ Aktif |
| Check-in (doğrulanmamış) | +15 | ✅ Aktif |
| Check-in (EXIF doğrulamalı) | +30 | ❌ EXIF kaldırıldı, tetiklenmiyor |
| Doğru oy almak | +10 | ✅ Aktif |
| Gölge puan (başkası merana gider) | +20 | ⚠️ Edge Function yok |
| Yanlış rapor cezası | -20 | ✅ Tetikleyici aktif |

**Rütbe eşikleri:**
```
Acemi (🪝) →[500]→ Olta Kurdu (🎣) →[2000]→ Usta (⚓) →[5000]→ Deniz Reisi (🌊)
```

**Rütbenin önemi:** `usta` ve `deniz_reisi` rütbeleri VIP meralara RLS seviyesinde erişim sağlar. Rütbe DB'den okunur; istemci manipüle edemez.

**Mera Muhtarı:** `fishing_spots.muhtar_id` alanı şemada var ama rotasyon/atama mekanizması henüz kodlanmamış.

### 3.3 Check-in ve Oylama Döngüsü

```
1. Kullanıcı "Buraya Geldim" → CheckinScreen
2. GPS ile 500m konum kontrolü (istemci tarafı)
3. checkins tablosuna INSERT
4. score-calculator çağrısı (unawaited — fire-and-forget)
5. notification-sender → favori sahiplerine + yakındaki (2km) kullanıcılara push
6. Realtime kanal → diğer harita ekranlarında pin güncellenir

Oylama (community moderation):
- 3+ oy + %70 "Yanlış" → is_hidden = true (SECURITY DEFINER trigger)
- Gizlenen check-in skoru: -20 puan
```

### 3.4 Bildirim Sistemi

**Push gönderim zinciri:**
```
Tetikleyici (pg_cron / Flutter çağrısı)
    └→ notification-sender Edge Function
         ├─ Günlük limit: max 5 push/gün (force=true bildirimleri sayılmaz)
         ├─ Sessiz mod: 23:00–07:00 İstanbul (push atlanır, in-app kaydedilir)
         ├─ FCM V1 API (OAuth2 service account ile JWT üretimi)
         └─ notifications tablosuna INSERT (in-app + push birlikte)
```

**Zamanlanmış görevler:**
```
0 3 * * *  → morning-weather-push (06:00 İst.) — sabah hava bildirimi
0 7 * * *  → season-reminder-push (10:00 İst.) — sezon hatırlatması
0 * * * *  → weather-cache güncellemesi
```

**Deep Link haritası (push tıklanınca):**
```
checkin / vote  → /home + spot_id (mera sheet açılır)
rank_up         → /rank (sıralama sekmesi)
follow          → /profile/:userId
season_reminder → /weather
weather_morning → /weather   ⚠️ NOT: Şu an /home'a düşüyor (bug)
```

---

## 4. Veritabanı Şeması ve Güvenlik

### 4.1 Kritik Tablolar

```sql
users           -- Profil, puan, rütbe, fcm_token
fishing_spots   -- Merallar: lat/lng, privacy_level, muhtar_id
checkins        -- Balık bildirimleri: is_hidden, true_votes, false_votes
checkin_votes   -- Topluluk oyları (voter_id UNIQUE per checkin)
notifications   -- In-app + push log
notification_settings -- Kategori bazlı opt-out (weather_morning, season_reminder, checkin_nearby)
weather_cache   -- Saatlik hava verisi (region_key UNIQUE)
fish_logs       -- Kişisel av günlüğü
fish_season_calendar  -- Sezon açılış tarihleri (notify_days_before)
fish_season_push_log  -- Çift gönderim önleme (idempotency)
spot_favorites  -- Favori meralar
shadow_points   -- Gölge puan kayıtları (RLS henüz tanımlı değil!)
```

### 4.2 Mera Gizlilik Seviyeleri (RLS)

| `privacy_level` | Kimlere Görünür |
|----------------|----------------|
| `public` | Herkes (anonim dahil) |
| `friends` | Tek yönlü takip edenler (karşılıklı onay gerekmez — bilinen açık) |
| `private` | Yalnızca sahip |
| `vip` | `usta` veya `deniz_reisi` rütbeli authenticated kullanıcılar |

**Önemli:** RLS kuralları DB seviyesinde; Flutter istemcisi atlatamaz. Rütbe JWT'den değil, `users` tablosundan okunur.

### 4.3 Storage Bucket'ları

| Bucket | Public | Limit | MIME Kısıtı |
|--------|--------|-------|-------------|
| `users-avatars` | ✅ | 2MB | jpeg, png, webp |
| `fish-photos` | ✅ | 2MB | ❌ YOK (güvenlik açığı) |

---

## 5. Geliştirici Ortamı Kurulumu

### 5.1 Ön Gereksinimler

```
Flutter SDK ≥ 3.11 (dart ≥ 3.11.1)
Android Studio / VS Code
Supabase CLI (npm install -g supabase)
Node.js ≥ 18 (Edge Function geliştirme için)
```

### 5.2 Adım Adım Kurulum

```bash
# 1. Repoyu klonla
git clone <repo-url>
cd balikci-app

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Drift ve Riverpod code generation çalıştır
dart run build_runner build --delete-conflicting-outputs

# 4. Ortam değişkenlerini ayarla
cp .env.example .env
# .env içini doldur:
#   SUPABASE_URL=https://bcsihxgekoqwbovbmlog.supabase.co
#   SUPABASE_ANON_KEY=<anon_key>

# 5. Firebase kurulumu
# android/app/google-services.json dosyasını Firebase Console'dan indir
# ios/Runner/GoogleService-Info.plist (iOS için)

# 6. Uygulamayı çalıştır
flutter run
```

### 5.3 Ortam Değişkenleri

`.env` dosyasında (projeye asset olarak eklenmeli — `pubspec.yaml` zaten tanımlı):

| Değişken | Açıklama |
|----------|----------|
| `SUPABASE_URL` | Proje URL |
| `SUPABASE_ANON_KEY` | Public anon key (publishable) |

**Edge Function ortam değişkenleri** (Supabase Dashboard > Settings > Secrets):

| Secret | Açıklama |
|--------|----------|
| `FIREBASE_SERVICE_ACCOUNT_B64` | FCM için Base64 kodlanmış service account JSON |
| `SUPABASE_SERVICE_ROLE_KEY` | Otomatik inject; manuel set gerekmez |

### 5.4 Code Generation

Drift veya model değişikliği sonrası:
```bash
dart run build_runner build --delete-conflicting-outputs
# veya watch modunda:
dart run build_runner watch --delete-conflicting-outputs
```

`database.g.dart` bu komutla üretilir. Git'e commit edilmiş halde bulunur.

### 5.5 Supabase Migration'ları Uygulama

```bash
# Migration'ları sırayla Supabase SQL Editor'da çalıştır:
supabase/migrations/
  ├── 20240002_exif_storage_trigger.sql
  ├── 20260409_spot_favorites.sql
  ├── 20260411_storage_users_avatars_bucket.sql
  ├── 20260412_leaderboard_rpc_friend_requests.sql
  ... (tarih sırasıyla)

# Cron job'ları ayrıca çalıştır:
supabase/cron_weather.sql
supabase/cron_morning_weather_push.sql
supabase/cron_season_reminder_push.sql
```

### 5.6 Edge Function Deploy

```bash
supabase functions deploy weather-cache
supabase functions deploy score-calculator
supabase functions deploy notification-sender
supabase functions deploy morning-weather-push
supabase functions deploy season-reminder-push
supabase functions deploy nearby-checkin-notifier
supabase functions deploy exif-verify   # Şu an aktif trigger'a bağlı değil
```

---

## 6. Teknik Borçlar ve Bilinen Sorunlar

### 🔴 Kritik (Hemen Düzeltilmeli)

| # | Sorun | Konum | Düzeltme |
|---|-------|-------|---------|
| 1 | `score-calculator` user_id parametresi JWT ile doğrulanmıyor | `supabase/functions/score-calculator/index.ts` | JWT'den `auth.uid()` çek, body'deki user_id'yi yoksay |
| 2 | `fish-photos` bucket'ta MIME tipi kısıtlaması yok | `20260415_storage_fish_photos_bucket.sql` | `allowed_mime_types` ekle |
| 3 | `20240002_exif_storage_trigger.sql`'de placeholder key | `'Bearer BURAYA_SERVICE_ROLE_KEY_YAZ'` | Vault referansına geçir |
| 4 | `shadow_points` tablosunda RLS yok | DB şeması | `ENABLE ROW LEVEL SECURITY` + policy ekle |

### 🟠 Yüksek Öncelikli Eksiklikler

| # | Sorun | Açıklama |
|---|-------|---------|
| 5 | `weather_morning` push tipi yanlış rotaya gidiyor | `/home`'a düşüyor, `/weather`'a gitmeli — `_routeForType` switch'i |
| 6 | Edge Functions JWT doğrulaması yok | `weather-cache`, `morning-weather-push` anonim erişime açık → maliyet saldırısı riski |
| 7 | `gölge-point-calculator` Edge Function yok | `shadow_points` tablosu hazır ama hesaplama fonksiyonu kodlanmamış |
| 8 | Mera muhtarı rotasyon mekanizması yok | `muhtar_id` alanı var ama atama/rotasyon otomasyonu yok |
| 9 | `checkin_verified` (+30 puan) hiç tetiklenmiyor | EXIF doğrulama akışı kaldırıldı; ya yeni doğrulama yöntemi ya da bu puan kaynağını kaldır |

### 🟡 Orta Öncelikli İyileştirmeler

| # | Sorun | Açıklama |
|---|-------|---------|
| 10 | `_buildMarkers()` her `setState`'te 500 marker yeniden üretiliyor | Cache'le; sadece `_spots` değişince yeniden hesapla |
| 11 | Arama kutusuna her odaklanmada GPS(high) çağrısı | 60 saniye pozisyon cache'i ekle |
| 12 | `signOut` anında `fcm_token` null'a çekilmiyor | Hayalet bildirim riski (gizlilik) |
| 13 | `morning-weather-push` aktif kullanıcı limit sorunu | `.limit(1000)` ile kullanıcı atlıyor; DISTINCT RPC kullan |
| 14 | "Friends" meraları tek yönlü takiple görünüyor | Karşılıklı follow (arkadaşlık) şartı aranmalı |
| 15 | `unreadCountProvider` her görsel yenilemede yeni sorgu | Gerçek zamanlı notifications stream'e geç |

### 📋 Mimari Notlar (Yeni Geliştirici İçin)

- **Routing:** Asla `context.go('/literal-path')` kullanma. Her zaman `AppRoutes.xxx` sabitlerini kullan.
- **Supabase Sorguları:** Her zaman `try-catch` ile sar. Hata mesajları Türkçe ve kullanıcı dostu olmalı.
- **`unawaited()`:** Fire-and-forget olarak bilinçli kullanılan yerler var (score award, notification). Kasıtsız kullanmaktan kaçın.
- **`mounted` Kontrolü:** Her `async` metodun `await` sonrasında `if (!mounted) return;` kontrolü yapılmalı.
- **`flutter analyze`:** Her commit öncesi çalıştır; sıfır hata/uyarı zorunlu.
- **Drift Migration:** `schemaVersion` artırmayı ve `onUpgrade` zincirini bozmamayı unutma.
- **Commit Dili:** Türkçe, açıklayıcı commit mesajları (`feat: Mera düzenleme ekranı eklendi`).

---

## 7. CI/CD ve Yayınlama Süreci

### 7.1 Mevcut CI/CD Durumu

**Sonuç: Otomatik CI/CD pipeline yok.** `.github/` klasörü yalnızca `.github/java-upgrade/hooks/` içeren boş bir dizin; hiçbir GitHub Actions workflow dosyası (`.yml`) mevcut değil. Codemagic veya Fastlane yapılandırması da bulunamadı.

Tüm build ve yayın adımları **manuel** olarak yapılmaktadır.

### 7.2 Android Release Build Alma

`android/app/build.gradle.kts` imzalama yapılandırması `key.properties` dosyasına bağlıdır:

```kotlin
// build.gradle.kts içinde:
val keyPropertiesFile = rootProject.file("key.properties")
// key.properties varsa release imzası, yoksa debug imzası kullanılır
```

**Adım adım release build:**

```bash
# 1. Keystore dosyasını oluştur (ilk seferinde)
keytool -genkey -v -keystore balikci-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias balikci

# 2. android/key.properties dosyasını oluştur (git'e commit etme!)
storePassword=<keystore_sifresi>
keyPassword=<key_sifresi>
keyAlias=balikci
storeFile=../../balikci-release.jks

# 3. Release APK / App Bundle üret
flutter build apk --release
# veya Play Store için:
flutter build appbundle --release

# 4. Çıktı konumu:
# APK:    build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

> **⚠️ Kritik:** `key.properties` ve `*.jks` dosyaları `.gitignore`'da. Bu dosyaları **asla Git'e commit etme.** Ekip içinde güvenli paylaşım için şifre yöneticisi (1Password, Bitwarden) kullan.

### 7.3 Build Ayarları

| Parametre | Değer |
|-----------|-------|
| `applicationId` | `com.balikciapp.balikci_app` |
| `compileSdk` | Flutter SDK varsayılanı |
| `minSdk` | Flutter SDK varsayılanı |
| `isMinifyEnabled` | `true` (release) |
| `isShrinkResources` | `true` (release) |
| ProGuard | `proguard-rules.pro` ile özelleştirilmiş |
| Core Library Desugaring | `desugar_jdk_libs:2.1.2` |

### 7.4 Önerilen İlerideki CI/CD Adımı

Projenin olgunluğu arttıkça GitHub Actions kurulması önerilir:

```yaml
# .github/workflows/flutter_ci.yml — ÖNERİ (şu an mevcut değil)
on: [push, pull_request]
jobs:
  analyze_and_test:
    steps:
      - flutter pub get
      - dart run build_runner build
      - flutter analyze          # sıfır hata zorunlu
      - flutter test             # tüm testler yeşil
```

---

## 8. Gözlemlenebilirlik (Observability) ve Hata Takibi

### 8.1 Mevcut Durum

**Firebase Crashlytics, Sentry veya Mixpanel entegrasyonu mevcut değil.** `pubspec.yaml` ve tüm Dart dosyaları tarandı; herhangi bir hata takip veya analitik paketi bulunamadı.

| Araç | Durumu |
|------|--------|
| Firebase Crashlytics | ❌ Entegre değil |
| Firebase Analytics | ❌ Entegre değil |
| Sentry | ❌ Entegre değil |
| Supabase Logs | ✅ Mevcut (manuel inceleme) |

### 8.2 Production Hataları Şu An Nasıl İzleniyor?

1. **Supabase Dashboard → Logs:** Edge Function hataları ve DB sorgu hataları buradan izlenebilir.
2. **`debugPrint()`:** Kodda `print()` hiç yok; tüm loglar `debugPrint` ile yazılıyor — bu loglar yalnızca debug build'de görünür, production'da sessizdir.
3. **`main.dart` `startupErrors` listesi:** Uygulama başlarken kritik hatalar (`.env` eksik, Firebase başlamadı vb.) `StartupErrorScreen`'de kullanıcıya gösterilir.

### 8.3 Kritik Eksiklik ve Öneri

Production'da kullanıcının yaşadığı hatalar şu an **hiçbir sistemde kayıt altına alınmıyor.** İlk release öncesinde:

```yaml
# pubspec.yaml'a eklenecek:
firebase_crashlytics: ^4.x.x
firebase_analytics: ^11.x.x
```

```dart
// main() içinde, Firebase.initializeApp() sonrası:
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

---

## 9. Ortam Yönetimi (Staging vs. Production)

### 9.1 Mevcut Durum: Tek Ortam

Projede şu an **yalnızca production Supabase projesi** kullanılıyor. Staging/test ortamı ayrımı yapılmamış.

`.env` dosyası:
```
SUPABASE_URL=https://bcsihxgekoqwbovbmlog.supabase.co   ← Production
SUPABASE_ANON_KEY=sb_publishable_UrBz2yJnupWn1Hy__...   ← Production
```

### 9.2 Geliştiricinin Canlıyı Bozmama Kuralları

Tek ortam olduğu için aşağıdaki kurallara uyulması zorunludur:

1. **Test kullanıcısı oluştur:** Production'da gerçek kullanıcı verilerini etkilememek için test e-postası kullan (`test+dev@domain.com` gibi).
2. **Test meraları:** `privacy_level = 'private'` olan meraları test için kullan; herkese açık test verisi ekleme.
3. **Edge Function test:** Supabase Dashboard → Functions → Logs üzerinden manuel tetikle; Production cron'u bozma.
4. **Migration dikkat:** SQL migration'larını **önce yerel Supabase instance'ında** test et.

### 9.3 Önerilen Staging Kurulumu (İleri Faz)

```
Supabase Dashboard → New Project → "balikci-staging"
```

```
# .env.staging
SUPABASE_URL=https://<staging-id>.supabase.co
SUPABASE_ANON_KEY=<staging_anon_key>
```

```bash
# Staging build:
flutter run --dart-define=ENV=staging
# Bu yaklaşım için main.dart'ta ortam ayrımı kodu gerekir.
```

---

## 10. Test Stratejisi

### 10.1 Mevcut Test Yapısı

Proje **aktif bir test suite'ine** sahip. Toplam: **~27 test dosyası**, 3 kategoride:

```
test/
├── core/                         # Servis ve utility testleri (5 dosya)
│   ├── avatar_image_prepare_test.dart
│   ├── istanbul_ilce_resolver_test.dart
│   ├── mera_weather_display_test.dart
│   ├── notification_routing_test.dart
│   └── weather_service_hourly_test.dart
│
├── models/                       # Model parse ve logic testleri (10 dosya)
│   ├── checkin_model_test.dart
│   ├── hourly_weather_model_test.dart
│   ├── user_model_test.dart
│   ├── weather_model_test.dart
│   ├── spot_model_test.dart
│   ├── stats_calculations_test.dart
│   └── ... (diğerleri)
│
├── utils/                        # Hesaplama ve yardımcı testleri (7 dosya)
│   ├── fishing_weather_utils_test.dart
│   ├── geo_utils_test.dart
│   ├── score_utils_test.dart
│   ├── moon_phase_utils_test.dart
│   └── ... (diğerleri)
│
└── widget/                       # Widget render testleri (11 dosya)
    ├── spot_marker_test.dart
    ├── rank_badge_test.dart
    ├── knot_detail_screen_test.dart
    ├── reset_password_screen_test.dart
    └── ... (diğerleri)
```

### 10.2 Testleri Çalıştırma

```bash
# Tüm testleri çalıştır:
flutter test

# Belirli bir test dosyası:
flutter test test/models/checkin_model_test.dart

# Belirli bir klasör:
flutter test test/utils/

# Coverage raporu:
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 10.3 Test Kapsamı Durumu

| Katman | Kapsam | Notlar |
|--------|--------|--------|
| Models (parse/serialize) | ✅ İyi | Tüm kritik modeller test edilmiş |
| Utility fonksiyonlar | ✅ İyi | `GeoUtils`, `ScoreUtils`, hava hesaplamaları |
| Widget render | ✅ Orta | Temel widget'lar var |
| Repository/Servis | ❌ Yok | Supabase mock'u gerektiriyor |
| Integration/E2E | ❌ Yok | Henüz yazılmamış |

### 10.4 Yeni Özellik İçin Test Yazma Standardı

- **Model değişikliği:** `test/models/` altına `fromJson` ve iş mantığı testi ekle.
- **Utility fonksiyon:** `test/utils/` altına kenar durumlarla birlikte test ekle.
- **Yeni widget:** `test/widget/` altına en az bir `render` testi ekle.
- **Kural:** Her commit öncesi `flutter test` yeşil olmalı.

```bash
# Commit öncesi kontrol scripti:
flutter analyze && flutter test
# İkisi de başarılıysa commit at.
```

---

## 11. Offline Senkronizasyon — SyncQueue Mekanizması

### 11.1 Genel Mimari

`SyncService` (`lib/core/services/sync_service.dart`), internet yokken gerçekleştirilen yazma işlemlerini `sync_queue` SQLite tablosuna kaydeder; bağlantı gelince otomatik olarak Supabase'e iletir.

```
Kullanıcı (offline)
    └→ Repository.insert/update/delete()
         └→ Önce Supabase dener → başarısız
         └→ SyncService.enqueue(operation, tableName, payload)
              └→ sync_queue tablosuna SQLite INSERT

Bağlantı gelince:
connectivity_plus stream → SyncService.processQueue()
    └→ sync_queue tablosunu createdAt ASC sırasıyla oku
    └→ Her satır için Supabase'e insert/update/delete
    └→ Başarılıysa → satırı sil
    └→ Hata varsa → retryCount++; max 5 deneme; 5'te sil
```

### 11.2 SyncQueue Tetiklenme Mekanizması

`main.dart`'ta `SyncService.instance.startListening()` çağrılır ve **üç mekanizma** ile çalışır:

| Mekanizma | Açıklama |
|-----------|---------|
| `connectivity_plus` stream | Offline→online geçişinde **anında** tetiklenir |
| Başlangıç kontrolü | Uygulama açılınca çevrimiçiyse kuyruk hemen işlenir |
| 30 sn periyodik poll | Deep-sleep veya stream kaçması durumuna karşı yedek |

### 11.3 Retry Stratejisi

```dart
if (nextRetry > 5) {
  // 5 denemede başarısız → kalıcı hata, kuyruktan sil
  await db.delete(syncQueue).where((t) => t.id.equals(row.id)).go();
  debugPrint('SyncService: İşlem kalıcı hata — silindi');
  continue;
}
// Değilse retryCount artır ve bir sonraki processQueue'da tekrar dene
```

**Önemli:** Retry aralarında **bekleme süresi (backoff) yok.** `processQueue()` her tetiklendiğinde tüm satırları dener. Bu, kısa süre içinde tekrar tetiklenirse aynı işlemin hızlıca 5 denemeye ulaşabileceği anlamına gelir.

### 11.4 Hangi Operasyonlar Destekleniyor?

| Operasyon | Payload Gereksinimi |
|-----------|-------------------|
| `insert` | Tüm alan değerleri |
| `update` | `id` alanı zorunlu + güncellenecek alanlar |
| `delete` | `id` alanı zorunlu |

### 11.5 Bilinen Sınırlılıklar

1. **Backoff yok:** Ağ geçici hata verirse aynı saniye içinde 5 deneme tüketilebilir.
2. **Çakışma çözümü yok:** Offline iken yapılan bir güncelleme, başka bir kullanıcının online güncellediği bir satırla çakışırsa "last-write-wins" değil, hata olur.
3. **Sadece yazma işlemleri:** Okuma işlemleri SyncQueue'ya girmez; okumalar Drift local cache'ten yapılır.
4. **Transaction garantisi yok:** Birden fazla tabloya yazma gerektiren bir işlem (örn. check-in + puan güncellemesi) atomik olarak kuyruğa alınamaz.

---

## Hızlı Başlangıç Kontrol Listesi

İlk günün sonunda bunları tamamlamış olmalısın:

- [ ] `flutter pub get` ve `build_runner build` başarılı
- [ ] `.env` dosyası oluşturuldu ve `SUPABASE_URL` + `SUPABASE_ANON_KEY` dolu
- [ ] `google-services.json` yerleştirildi
- [ ] `flutter run` ile uygulama emülatörde açıldı
- [ ] `flutter test` — tüm testler yeşil
- [ ] `docs/ARCHITECTURE.md` okundu
- [ ] `docs/MVP_PLAN.md` okundu (sprint geçmişi)
- [ ] Bu dosyadaki **6. bölüm** (Tech Debt) dikkatle incelendi

İlk haftanın sonunda:
- [ ] Check-in akışını uçtan uca test et (test kullanıcısıyla)
- [ ] `supabase/functions/` altındaki tüm Edge Function'ları oku
- [ ] Offline senaryoyu test et: Uçak modunda check-in yap, internet aç, SyncQueue'nun tetiklendiğini doğrula
- [ ] Mevcut analiz raporlarını oku: `GAMIFICATION_ANALYSIS.md`, `NOTIFICATION_ANALYSIS.md`, `SECURITY_ANALYSIS.md`, `LOCATION_BATTERY_ANALYSIS.md`

---

## 12. State Management — Riverpod Mimari Kuralları

### 12.1 Projede Kullanılan Provider Türleri

Proje **Riverpod 2.x** ile çalışıyor. Kod tabanında kullanılan provider türleri ve kullanım amaçları:

| Provider Türü | Kullanım Amacı | Örnekler |
|--------------|----------------|---------|
| `AsyncNotifierProvider` | Kullanıcı aksiyonlarına cevap veren, loading/error state'i olan iş mantığı | `authNotifierProvider` (giriş/çıkış/kayıt) |
| `NotifierProvider` | Senkron state değişiklikleri | `onboardingStateProvider` (SharedPreferences) |
| `FutureProvider.autoDispose` | Ekran açıldığında veri çek, kapanınca dispose et | `currentUserProfileProvider`, `leaderboardProvider`, `myFishLogsProvider` |
| `FutureProvider` (kalıcı) | Uygulama boyunca cache'lenmesi gereken veri | `fishingScoreEngineProvider` (`ref.keepAlive()` ile), `fishEncyclopediaProvider` |
| `StreamProvider` | Gerçek zamanlı veri akışı | `authStateProvider`, `connectivityProvider` |
| `Provider` | Senkron, hesaplanmış değer | `isLoggedInProvider`, `currentUserProvider`, `routerProvider` |
| `StateProvider` | Basit UI state (seçim, filtre) | `selectedFishCategoryProvider` (balık ansiklopedisi kategorisi) |
| `.family` | Parametre alan provider | `userProfileProvider(userId)`, `isFavoriteProvider(spotId)` |

**`StateNotifierProvider` ve `ChangeNotifier` kullanılmıyor.** Tek istisna: `go_router` entegrasyonu için `GoRouterRefreshStream extends ChangeNotifier` — bu doğrudan Riverpod state değil, router refresh için zorunlu.

### 12.2 İş Mantığının Katman Haritası

```
UI Widget (build metodu)
    ↕ ref.watch / ref.read
Provider (FutureProvider / AsyncNotifier)
    ↕ await / stream
Repository (SpotRepository, CheckinRepository…)
    ↕ Supabase SDK / Drift ORM
SupabaseService.client / AppDatabase.instance
```

**Kural:** İş mantığı widget'lara değil, **service veya repository sınıflarına** yazılır. `AsyncNotifier`'lar yalnızca UI aksiyonlarını (signIn, signOut gibi) repository'ye iletir; hesaplama yapmaz. Karmaşık hesaplamalar `lib/core/services/` veya `lib/core/utils/` altındaki sınıflara gider.

**Doğru örnek:**
```dart
// ✅ İyi: Mantık ScoreUtils'te, widget sadece görüntüler
Text(ScoreUtils.rankFromScore(user.totalScore))

// ❌ Yanlış: İş mantığı widget build() içinde
Text(score >= 5000 ? 'Deniz Reisi' : score >= 2000 ? 'Usta' : 'Acemi')
```

### 12.3 `autoDispose` Kuralı

- Ekrana özel (geçici) veriler: `FutureProvider.autoDispose` — ekran kapanınca Riverpod cache'i temizler.
- Uygulama boyunca paylaşılan veri: `FutureProvider` + `ref.keepAlive()` — ilk çağrıda yükle, tekrar sorgu yok.

```dart
// Balık ansiklopedisi — uygulama boyunca cache'le
final fishEncyclopediaProvider = FutureProvider<List<FishEncyclopediaEntry>>((ref) async {
  ref.keepAlive();  // ← dispose edilmez
  ...
});
```

---

## 13. Kimlik Doğrulama ve Oturum Yönetimi Detayları

### 13.1 Auth Akışı Özeti

```
Kayıt (signUp)
  → Supabase Auth → e-posta onay linki gönderilir
  → Session açılırsa ensureUserProfile() çağrılır
  → DB'de users satırı oluşturulur (trigger veya istemci yedek)
  → Onboarding ekranına yönlendirilir

Giriş (signIn - e-posta/şifre)
  → Supabase Auth.signInWithPassword()
  → ensureUserProfile() — kullanıcı satırı garantilenir
  → authStateProvider stream'i ateşlenir
  → go_router redirect kural → /home veya /onboarding

Google OAuth (signInWithGoogle)
  → signInWithOAuth(OAuthProvider.google, redirectTo: 'balikciapp://...')
  → Sistem tarayıcısı açılır
  → Kullanıcı Google ile oturum açar
  → Deep link: balikciapp://... → AppLinks'e düşer → getSessionFromUrl()
  → authStateProvider stream'i ateşlenir → router redirect
```

### 13.2 Şifre Sıfırlama Deep Link Zinciri

```
1. resetPassword(email) → resetPasswordForEmail(redirectTo: 'balikciapp://reset-callback/')
2. Kullanıcı e-postadaki linke tıklar
3. OS balikciapp:// scheme'ini yakalar → AppLinks.uriLinkStream tetiklenir
4. main.dart: getSessionFromUrl(uri) → oturum açılır
5. authStateProvider → AuthChangeEvent.passwordRecovery
6. main.dart listener: context.go(AppRoutes.resetCallback) → ResetPasswordScreen
```

**Android manifest'te tanımlı:** `balikciapp://` scheme deep link olarak kayıtlı (`app_links` paketi).

### 13.3 Token Yenileme ve Session Süresi

Supabase Flutter SDK **otomatik token yenileme** yapar — uygulamanın bunu manuel yönetmesine gerek yok. Session süresi dolduğunda:

1. `onAuthStateChange` stream → `AuthChangeEvent.signedOut` event'i
2. `authStateProvider` güncellenir
3. `routerProvider` — `GoRouterRefreshListenable` tetiklenir
4. `redirect` fonksiyonu: `!isLoggedIn` → `/login` sayfasına yönlendirilir

**Kullanıcı sessizce login sayfasına atılır; dialog veya snackbar yok.** Bu 45+ amca stratejisinin bir parçası: "Teknik mesaj yok, sadece giriş yap ekranı."

### 13.4 `ensureUserProfile` — Çift Güvenlik Mekanizması

`public.users` satırı iki katmanda güvence altında:

1. **Supabase DB Trigger** (birincil): `auth.users`'a INSERT gelince otomatik `public.users` satırı açar.
2. **`ensureUserProfile()`** (istemci yedek): signIn/signUp başarılıysa istemci de kontrol eder; satır yoksa oluşturur.

Yeni geliştirici trigger'ı silmemeli veya değiştirmemeli; her iki katman da korunmalı.

### 13.5 Hata Mesajları Türkçe Haritalama

`_mapAuthError()` metodu İngilizce Supabase/Auth hata mesajlarını Türkçe ve kullanıcı dostu ifadelere çevirir:

```dart
'invalid login credentials' → 'Email veya şifre hatalı'
'already registered'        → 'Bu email adresi zaten kullanımda'
'network' / 'connection'    → 'Bağlantı hatası, lütfen tekrar deneyin'
```

**Kural:** Auth hata mesajları asla İngilizce gösterilmez. Yeni auth akışı eklerken bu metodu güncelle.

---

## 14. UI/UX Standartları ve Tema Sistemi

### 14.1 Merkezi Tema Dosyası: `lib/app/theme.dart`

Tüm renk, tipografi ve component stilleri bu dosyada tanımlı. Widget içinde asla hardcoded renk veya font boyutu kullanma.

### 14.2 Renk Paleti (`AppColors`)

**Balıkçı temasına özel okyanus paleti — koyu mod (dark-first):**

| Sabit | Hex | Kullanım |
|-------|-----|---------|
| `primary` | `#0F6E56` | Ana buton, FAB, seçili durum |
| `navy` | `#0A1628` | Derin arka plan |
| `teal` | `#0D7E8A` | Mera pin (public), vurgular |
| `sand` | `#C9A84C` | VIP/Deniz Reisi rengi, altın aksan |
| `foam` | `#F0F8FF` | Açık metin, buton yazısı |
| `background` | `#07101E` | Scaffold arka planı |
| `surface` | `#0B1C33` | Kart yüzeyi |
| `danger` | `#E63946` | Hata, silme, uyarı |
| `success` | `#2FBF71` | Başarı, online göstergesi |
| `muted` | `#8EA0B5` | İkincil metin, disabled |

**Mera gizlilik seviyesi pinleri:**
```dart
pinPublic   → AppColors.teal    // Herkese açık
pinFriends  → AppColors.secondary (mavi)
pinPrivate  → AppColors.muted   // Gri, dikkat çekmez
pinVip      → AppColors.sand    // Altın, özel his
```

**Rütbe renkleri:**
```dart
rankAcemi      → AppColors.muted
rankOltaKurdu  → AppColors.secondary (mavi)
rankUsta       → AppColors.teal
rankDenizReisi → AppColors.sand
```

### 14.3 Tipografi (`AppTextStyles`)

Font ailesi: **Poppins** (Google Fonts — display). Sistem fontuna fallback var.

```dart
AppTextStyles.h1     // 28sp, w800 — Ekran başlıkları
AppTextStyles.h2     // 22sp, w800 — Bölüm başlıkları
AppTextStyles.h3     // 18sp, w700 — Alt başlıklar
AppTextStyles.body   // 16sp, w500 — 45+ amca kuralı: min 16sp
AppTextStyles.caption // 14sp, w500 — Küçük yardımcı metin
```

**45+ Amca Kuralı kodda:**
- `ElevatedButton.minimumSize = Size.fromHeight(56)` — Büyük, basması kolay buton
- `AppBar.toolbarHeight = 60` — Standarttan yüksek AppBar
- `AppBar.titleTextStyle.fontSize = 20` — Başlık min 20sp
- `bodyLarge.fontSize = 16`, `bodyMedium.fontSize = 16` — İki body stili de 16sp

### 14.4 Dil Desteği (Localization)

**L10n/i18n entegrasyonu yok.** Tüm kullanıcıya gösterilen metinler Dart dosyaları içinde Türkçe olarak hardcoded. `intl` paketi yalnızca tarih/saat formatlama için kullanılıyor (`initializeDateFormatting('tr_TR')`).

**Kural:** Yeni eklenecek UI metinleri doğrudan Türkçe yazılır. Çok dil desteği ilerideki fazlar için kapsam dışı.

### 14.5 Paylaşılan Widget'lar

`lib/core/widgets/` sadece `splash_screen.dart` içeriyor. Projede `AmcaButton`, `ReisCard` gibi özel isimli merkezi component sınıfları yok. Ortak UI pattern'leri `theme.dart`'taki global tema üzerinden sağlanıyor (ElevatedButton, Card vb. doğrudan Material widget'lar, tema ile şekillendirilmiş).

**Her özellik kendi widget'larını** `features/<feature>/widgets/` altında tutuyor.

---

## 15. Harita Tile Cache ve Marker Cluster Detayları

### 15.1 Tile Cache Stratejisi

Projede `flutter_map_tile_caching` paketi **kullanılmıyor**. Tile caching yalnızca `flutter_map` yerleşik mekanizmasıyla:

```dart
CancellableNetworkTileProvider()  // HTTP iptal desteği
keepBuffer: 8    // Mevcut zoom'un 8 satır ötesini hafızada tut
panBuffer: 3     // Kaydırma yönünde 3 tile önceden indir
tileDisplay: TileDisplay.instantaneous()  // Fade animasyonu yok (CPU tasarrufu)
```

**Disk cache yok.** Tile'lar yalnızca RAM'de tutulur; uygulama kapanınca sıfırlanır. Çevrimdışı harita desteği mevcut değil — bu bilinen bir kısıtlama.

### 15.2 Marker Cluster Yapılandırması

```dart
MarkerClusterLayerWidget(
  options: MarkerClusterLayerOptions(
    markers: _buildMarkers(),   // tüm mera Marker listesi
    maxClusterRadius: 58,       // 58 piksel yarıçapındaki pinler gruplanır
    size: const Size(42, 42),   // cluster dairesinin boyutu
    builder: (context, markers) {
      // markers.length sayısını gösteren daire
      return Container(/* primer renk daire + beyaz sayı */);
    },
  ),
)
```

**Cluster Zoom Eşiği:** `AppConstants.clusterZoomThreshold = 12.0` — bu sabit tanımlı ama `MarkerClusterLayerOptions`'a henüz bağlanmamış; cluster her zoom seviyesinde aktif. Zoom 12 altında cluster, 12 üstünde bireysel pin gösterimi için bu sabit ileriki optimizasyonda kullanılacak.

**Bounds-based yükleme:** Zoom ≥ 10.5 olduğunda haritanın görünür bölgesi için ek `getSpotsInBounds()` sorgusu atılır (520ms debounce). Bu yeni meraları `_spotMap`'e ekler ve cluster güncellenir.

---

## 16. Asset Yönetimi

### 16.1 Asset Klasörü Yapısı

```
assets/
├── fishing/               # JSON veri dosyaları
│   ├── fish_encyclopedia.json       # Balık ansiklopedisi (~220 tür)
│   ├── fish_species_istanbul.json   # İstanbul balık türleri ve sezonlar
│   ├── fishing_rules.json           # Avlanma kuralları
│   ├── istanbul_current_calendar.json  # Akıntı takvimi
│   └── moon_phase_rules.json        # Ay fazı balıkçılık kuralları
│
├── knots/
│   └── knots_data.json   # Düğüm rehberi verisi
│
├── tackle/               # Takım ekipman verisi (JSON)
│
├── images/
│   ├── logo.png          # Uygulama logosu (raster)
│   └── logo.svg          # Uygulama logosu (vektör)
│
└── icon/
    └── app_icon.png      # Launcher ikonu kaynağı
```

### 16.2 Asset Formatları ve Standartlar

| Tür | Format | Notlar |
|-----|--------|--------|
| Uygulama logosu | SVG + PNG | SVG tercih (vektör); PNG fallback |
| Launcher ikonu | PNG | `flutter_launcher_icons` ile üretilir |
| Balık/ekipman ikonları | **JSON içi URL veya emoji** | Ayrı ikon dosyaları yok; ansiklopedi JSON'ında metin/emoji kullanılıyor |
| Harita tile | Network (runtime) | Asset değil; ArcGIS CDN'den çekiliyor |
| Düğüm görselleri | JSON referans | Görsel URL veya base64 JSON içinde |

### 16.3 Yeni Asset Ekleme Kuralları

1. **`pubspec.yaml`'a kaydet:** Yeni klasör veya dosya eklenirse `flutter.assets` altına ekle.

   ```yaml
   assets:
     - assets/fishing/
     - assets/yeni_klasor/   # ← klasörü sona ekle
   ```

2. **Boyut limitleri:**
   - PNG/WebP görseller: maksimum 200KB (app bundle şişmesini önler)
   - JSON veri dosyaları: maksimum 500KB (büyükse Supabase'e taşı)

3. **İsimlendirme:** `küçük_harf_alt_çizgi.uzantı` (snake_case)

4. **SVG kullanımı:** `flutter_svg` paketi yüklü; `SvgPicture.asset()` ile kullan.

5. **Launcher ikonu güncelleme:**

   ```bash
   # assets/icon/app_icon.png değiştirildikten sonra:
   dart run flutter_launcher_icons
   ```

---

*Bu rehber, Mayıs 2026 itibarıyla projenin gerçek kaynak kodundan otomatik analiz ile üretilmiştir.*
