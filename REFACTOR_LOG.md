# Refactor Log — Balıkçı Super App

Tarih: 2026-04-03  
`flutter analyze` sonucu: **0 hata, 0 uyarı**

---

## Özet Tablosu

| Dosya | Sorun | Yapılan |
|-------|-------|---------|
| `lib/app/app_routes.dart` | Yok (yeni dosya) | Tüm route path sabitleri oluşturuldu |
| `lib/app/router.dart` | String literal path'ler | `AppRoutes.xxx` sabitleriyle değiştirildi |
| `lib/features/auth/login_screen.dart` | `context.go('/home')` vb. string path'ler | `AppRoutes` sabitleriyle değiştirildi |
| `lib/features/auth/register_screen.dart` | `context.go('/login')` vb. string path'ler | `AppRoutes` sabitleriyle değiştirildi |
| `lib/features/auth/splash_screen.dart` | `context.go('/home')` vb. string path'ler | `AppRoutes` sabitleriyle değiştirildi |
| `lib/features/auth/reset_password_screen.dart` | `context.go('/login')` | `AppRoutes.login` ile değiştirildi |
| `lib/features/auth/onboarding/onboarding_screen.dart` | `context.go('/home')` | `AppRoutes.home` ile değiştirildi |
| `lib/features/profile/settings_screen.dart` | `context.go('/login')` | `AppRoutes.login` ile değiştirildi |
| `lib/features/profile/profile_screen.dart` | `context.go('/fish-log')`, `context.push('/settings')` | `AppRoutes` sabitleriyle değiştirildi |
| `lib/features/map/map_screen.dart` | `context.push('/map/edit-spot')`, `context.push('/notifications')` | `AppRoutes` sabitleriyle değiştirildi |
| `lib/features/knots/knots_screen.dart` | `context.push('/knots/detail')` | `AppRoutes.knotsDetail` ile değiştirildi |
| `lib/features/main_shell.dart` | String `tabRoutes` listesi ve `startsWith` path karşılaştırmaları | `AppRoutes` sabitleriyle değiştirildi |
| `lib/core/services/notification_service.dart` | `_routeForType` switch içi string path'ler | `AppRoutes` sabitleriyle değiştirildi |
| `lib/data/repositories/user_repository.dart` | `select()` → tüm kolonlar çekiliyor | `select('id, email, username, ...')` ile daraltıldı |
| `lib/data/repositories/spot_repository.dart` | `select()` → tüm kolonlar çekiliyor (4 sorgu) | `select('id, user_id, name, lat, ...')` ile daraltıldı |
| `lib/data/repositories/fish_log_repository.dart` | `select()` → tüm kolonlar çekiliyor (3 sorgu) | `select('id, user_id, spot_id, ...')` ile daraltıldı |
| `lib/data/repositories/checkin_repository.dart` | `select()` → tüm kolonlar çekiliyor (4 sorgu) | `select('id, user_id, spot_id, ...')` ile daraltıldı |
| `lib/data/repositories/notification_repository.dart` | `select()` → tüm kolonlar çekiliyor | `select('id, user_id, type, ...')` ile daraltıldı |
| `lib/data/repositories/shop_repository.dart` | `select()` → tüm kolonlar çekiliyor | `select('id, name, lat, lng, ...')` ile daraltıldı |

---

## Bölüm Sonuçları

### 1. Envanter
- `flutter analyze` başlangıçta **0 hata** verdi; proje zaten lint-clean durumundaydı.
- `print()` çağrısı bulunamadı (zaten `debugPrint` kullanılıyordu).

### 2. Import & Dead Code
- Kullanılmayan import bulunmadı (`flutter analyze` baştan temizdi).
- Dead code tespit edilmedi.

### 3. Print → debugPrint
- Tüm dosyalar tarandı. `print(` çağrısı **sıfır** adet. Zaten `debugPrint` kullanılıyor.
- Değişiklik gerekmedi.

### 4. Async Context Güvenliği
- Tüm `async` widget metotları incelendi.
- `add_spot_screen.dart`, `checkin_screen.dart`, `settings_screen.dart`, `register_screen.dart`, `onboarding_screen.dart` dosyalarında `await` sonrası `if (!mounted) return;` kontrolü zaten mevcuttu.
- `login_screen.dart`: dialog içi `if (!mounted) return;` ve `if (dialogContext.mounted)` kontrolleri mevcut.
- Eksik `mounted` kontrolü bulunmadı; davranışsal değişiklik riski olmadığı için dokunulmadı.

### 5. Riverpod ref.watch/read
- Tüm provider dosyaları incelendi.
- `FutureProvider` / `StreamProvider` gövdelerinde `ref.read(repositoryProvider)` kullanımı kasıtlı tercih (repo singleton, state yok); `ref.watch` gerekmez.
- `build()` içinde `ref.watch(currentUserProvider)` doğru kullanılıyor.
- Event handler'larda `ref.read` kullanımı doğru.
- Değişiklik gerekmedi.

### 6. AppRoutes Sabitleri
- `lib/app/app_routes.dart` yeni dosyası oluşturuldu — tüm 32 route path sabiti tanımlandı.
- `router.dart` içindeki tüm string literal path'ler `AppRoutes.xxx` ile değiştirildi.
- `context.go(...)` / `context.push(...)` çağrıları 13 dosyada güncellendi:
  - `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`, `reset_password_screen.dart`
  - `onboarding_screen.dart`, `settings_screen.dart`, `profile_screen.dart`
  - `map_screen.dart`, `knots_screen.dart`, `main_shell.dart`
  - `notification_service.dart`

### 7. Widget Optimizasyonları
- `flutter analyze` baştan `const` uyarısı vermedi.
- `ListView(children: [...])` → `ListView.builder` dönüşümü: yalnızca dinamik-veri listelerinde anlamlı. `main.dart` ve `settings_screen.dart`'daki statik listeler küçük ve sabit; dönüştürülmedi.
- Değişiklik gerekmedi.

### 8. Supabase Select Kolon Optimizasyonu
- 6 repository dosyasında `select()` / `select('*')` → model `fromJson` kolonlarıyla daraltıldı:
  - `user_repository.dart`: 2 sorgu güncellendi
  - `spot_repository.dart`: 4 sorgu güncellendi  
  - `fish_log_repository.dart`: 3 sorgu güncellendi
  - `checkin_repository.dart`: 4 sorgu güncellendi (`getCheckinsForSpot` join içerdiğinden korundu)
  - `notification_repository.dart`: 1 sorgu güncellendi
  - `shop_repository.dart`: 1 sorgu güncellendi

### Korunan Dosyalar (Dokunulmadı)
| Dosya | Sebep |
|-------|-------|
| `lib/data/local/database.dart` | Drift migration zinciri v1→v2→v3 korunmalı |
| `lib/shared/providers/auth_provider.dart` | Oturum mantığı — kısıt |
| `lib/data/repositories/auth_repository.dart` | Oturum mantığı — kısıt |
| `lib/core/services/supabase_service.dart` | Singleton pattern korunmalı — kısıt |
| `SPRINT.md` | Kısıt |
| `lib/data/repositories/checkin_repository.dart` `getCheckinsForSpot` | `select('*, users:user_id(username)')` join içeriyor; daraltılırsa kullanıcı adı gelmez |
