# UI Audit — Backend/Frontend Entegrasyon Raporu

**Tarih:** 2026-04-11  
**Araç:** Claude Code — tam kesif analizi

---

## 1. BACKEND VAR, FRONTEND YOK (Entegre Edilmeli)

| Repository Metodu | Durum | Öncelik | Not |
|---|---|---|---|
| `FishLogRepository.updateLog()` | UI'da düzenleme yok | DÜŞÜK | Edit UI yok; delete+readd yeterli |
| `FollowRepository.getFollowerIds()` | UI'da kullanılmıyor | DÜŞÜK | Backend bildirim için; UI gerektirmiyor |
| `FollowRepository.getFollowingIds()` | UI'da kullanılmıyor | DÜŞÜK | Backend bildirim için |
| `CheckinRepository.updateCheckinPhotoUrl()` | ölü kod | KALDIR | Check-in fotoğrafı kaldırıldı |

---

## 2. FRONTEND VAR, BACKEND BAĞLI DEĞİL / ÖLÜ KOD

| Öğe | Sorun | Öncelik |
|---|---|---|
| `profile_screen.dart` "Rozetlerim" tile | `onTap: () {}` — hiçbir şey yapmıyor | YÜKSEK |
| `_FollowStatsRow._FollowStat.onTap` | `onTap: () {}` — tıklanabilir görünür ama boş | ORTA |
| `knot_filter_widget.dart` | Hiçbir ekranda kullanılmıyor (KnotsScreen kendi chip filtresi var) | KALDIR |

---

## 3. MANTIK DIŞI / TUTARSIZ UI

| Öğe | Sorun | Öncelik |
|---|---|---|
| `stats_screen.dart` | `StatefulWidget` + `SupabaseService.auth.currentUser?.id` doğrudan — rest of app Riverpod kullanıyor | YÜKSEK |
| `stats_screen.dart` boş durum | `Text('Henüz av kaydın yok.')` — `EmptyStateWidget` kullanılmıyor | YÜKSEK |
| `stats_screen.dart` font boyutu | `fontSize: 10` bar grafik etiketleri — hedef kitle (45+ yaş) için çok küçük | YÜKSEK |
| `StatsScreen._load()` | Pull-to-refresh yok | ORTA |

---

## 4. TUTARLILIK DENETİMİ

### AppBar stili
- ✅ Tüm ekranlar `AppBar` kullanıyor, tema tutarlı
- ✅ Geri butonu go_router tarafından otomatik ekleniyor

### Buton stilleri  
- ✅ Primary FAB: `AppColors.secondary` (turuncu)
- ✅ Primary action: `AppColors.primary` (mavi)
- ⚠️ Bazı ekranlarda `ElevatedButton` doğrudan tema yerine `backgroundColor` hardcode

### Boş durumlar
- ✅ `log_list_screen.dart` → `EmptyStateWidget.noFishLogs`
- ✅ `rank_screen.dart` → `_EmptyState`
- ✅ `notification_list_screen.dart` → `_NotificationEmptyState`
- ❌ `stats_screen.dart` → sadece `Text('Henüz av kaydın yok.')`

### Yükleme durumları
- ✅ `log_list_screen.dart`, `rank_screen.dart` → `SkeletonList`
- ❌ `stats_screen.dart` → sadece `CircularProgressIndicator` (skeleton yok)

### Hata durumları
- ✅ `log_list_screen.dart`, `rank_screen.dart` → `AppErrorWidget`
- ❌ `stats_screen.dart` → hata state'i hiç yok

### Dokunma hedefleri (48dp minimum)
- ✅ FAB'lar 56dp+ (ana FAB 72dp)
- ✅ NavItem 64dp yükseklik
- ✅ `_ActionTile` 48dp padding içeriyor
- ✅ IconButton Flutter default 48dp

### Metin boyutu (16sp minimum body)
- ✅ `AppTextStyles.body` = 16sp
- ❌ `stats_screen.dart` bar grafik: `fontSize: 10` (çok küçük)

---

## 5. ROUTER / NAVIGASYON

- ✅ Tüm route'lar `AppRoutes` sınıfından referans alıyor
- ✅ Derin link (`/map` extra: spotId) çalışıyor
- ✅ Shell route içindeki 4 sekme doğru
- ✅ `AppRoutes.notifications` → `NotificationListScreen` bağlı
- ✅ `AppRoutes.notificationsSettings` → `NotificationSettingsScreen` bağlı

---

## 6. YAPILAN DEĞİŞİKLİKLER (Bu Oturum)

### Entegrasyon
- [x] `StatsScreen` → `ConsumerWidget` Riverpod migration (`myFishLogsProvider`)
- [x] `StatsScreen` → `SkeletonList` loading state
- [x] `StatsScreen` → `AppErrorWidget` hata state'i
- [x] `StatsScreen` → `EmptyStateWidget.noFishLogs` boş state
- [x] `StatsScreen` → Pull-to-refresh eklendi
- [x] `StatsScreen` → Font boyutları düzeltildi (10→12sp)

### Profil İyileştirmesi
- [x] "Rozetlerim" (ölü buton) → "İstatistiklerim" (çalışan navigasyon: `/fish-log/stats`)
- [x] `_FollowStatsRow._FollowStat.onTap: () {}` → `GestureDetector` kaldırıldı (interaktif görünmemeli)

### Temizlik
- [x] `lib/features/knots/knot_filter_widget.dart` silindi (hiçbir yerde kullanılmıyor)
- [x] `CheckinRepository.updateCheckinPhotoUrl()` silindi (dead code)

---

## 7. KALAN BİLİNEN SORUNLAR

- **`FishLogRepository.updateLog()`** — Edit UI yok. Düşük öncelik.
- **`FollowRepository.getFollowerIds()/getFollowingIds()`** — UI'da gerekmiyor, sadece backend bildirimleri için var.
- **"Rozetlerim" sistemi** — Tam rozet sistemi (backend + UI) ileride eklenecek.
- **Bölgesel sıralama** (`RankScreen` Bölge sekmesi) — Kullanıcı bölge alanı henüz yok, placeholder.
