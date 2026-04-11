# Balıkçı Super App — 16 Haftalık Sprint Planı

> Kodla uyumlu kısa özet: [PROJECT_STATUS.md](PROJECT_STATUS.md)

> Her sprint başında bu dosyayı güncelle.
> Tamamlanan görevleri ✅, devam edenleri 🔄, bekleyenleri ⏳ ile işaretle.

---

## Sprint Özeti

| Faz | Haftalar | Odak | Durum |
|-----|---------|------|-------|
| Faz A | H1–H2 | Kurulum & Auth | ✅ |
| Faz B | H3–H6 | Harita & Check-in Çekirdeği | ✅ |
| Faz C | H7–H10 | Günlük, Puan, Hava, Bildirim | 🔄 (H10 kısmen ✓) |
| Faz D | H11–H13 | Offline & Motivasyon UI | ✅ (H11 ✅, H12 🔄, H13 ✅) |
| Faz E | H14–H16 | Test, Polish & Launch | ⏳ |

---

## FAZ A — Kurulum & Auth (H1–H2)

### H1 — Proje Kurulum
**Hedef:** Çalışan iskelet uygulama, tüm servisler bağlı

#### Görevler
- [x] Flutter projesi `flutter create` ile oluşturuldu
- [x] `pubspec.yaml` tüm paketler eklendi, `flutter pub get` temiz
- [x] Klasör yapısı `ARCHITECTURE.md`'e göre oluşturuldu
- [x] Supabase projesi oluşturuldu (supabase.com)
- [x] Tüm tablolar SQL ile oluşturuldu (`ARCHITECTURE.md` → Veritabanı Şeması)
- [x] RLS politikaları eklendi
- [x] Firebase projesi oluşturuldu, `google-services.json` eklendi
- [x] `.gitignore` güvenlik dosyaları eklendi
- [x] Android `build.gradle.kts` desugaring (Java 8 API) desteği eklendi
- [x] `supabase_service.dart` singleton yazıldı
- [x] `app/theme.dart` renk ve stil sabitleri eklendi
- [x] `app/router.dart` temel route'lar tanımlandı
- [x] İlk commit ve push yapıldı

**Çıktı:** `flutter run` çalışıyor, Supabase bağlantısı test edildi ✓

---

### H2 — Auth & Onboarding
**Hedef:** Kullanıcı kayıt olup giriş yapabiliyor

#### Görevler
- [x] `auth_repository.dart` yazıldı (signUp, signIn, signOut, getUser; OAuth + profil senkronu M-01 ile genişletildi)
- [x] `auth_provider.dart` Riverpod provider yazıldı
- [x] `login_screen.dart` — e-posta + şifre formu
- [x] `register_screen.dart` — kayıt formu, validasyon
- [x] go_router `redirect` — oturum kontrolü ve yönlendirme (`auth_gate.dart` yerine `router.dart`)
- [x] `onboarding_screen.dart` — 3 adımlı akış
- [x] `step_location.dart` — konum izni (geolocator)
- [x] `step_notification.dart` — bildirim izni (FCM)
- [x] `step_first_spot.dart` — hoş geldin / onboarding bitiş CTA
- [x] Onboarding: izin sonrası otomatik sayfa geçişi yok; **İleri** ile ilerleme; izin isteğe bağlı; konum/bildirim adımlarında KeepAlive + OS/`resumed` senkronu; Android `POST_NOTIFICATIONS`
- [x] go_router guard: giriş yapılmamışsa `/login`'e yönlendir
- [x] Google OAuth (istemci: deep link + Supabase PKCE + login/register UI) — Supabase Dashboard redirect URL ve Google provider’ı doğrulanmalı
- [ ] `public.users` tetikleyici + RLS production DB’de uygulandı mı ([supabase_fix_mera_insert.sql](supabase_fix_mera_insert.sql))
- [ ] E-posta onayı açık projede kayıt sonrası UX doğrulandı mı
- [ ] (İsteğe bağlı) JWT / token’ı Drift veya secure storage’da tutma — M-01 kapsamı dışı

**Çıktı:** Kullanıcı kayıt, giriş, onboarding akışını tamamlayabiliyor ✓

---

## FAZ B — Harita & Check-in Çekirdeği (H3–H6)

**Durum:** ✅ H3–H6 tamamlandı. **Sıradaki odak:** H10 kalan bildirim görevleri → H11 Düğüm Rehberi. **Haritada dükkan (`shops`) pinleri** planın sonuna alındı (bkz. H15).

### H3 — Harita Temeli ✅

#### Görevler
- [x] `map_screen.dart` — FlutterMap widget entegrasyonu
- [x] OpenStreetMap tile provider bağlandı
- [x] `spot_repository.dart` yazıldı (getSpots, getSpotsInBounds, addSpot, updateSpot, Drift cache)
- [x] `spot_model.dart` ve Drift şeması oluşturuldu / genişletildi (`verified`, `muhtarId`, `cachedAt`)
- [x] Mera pinleri haritada gösteriliyor (privacy_level'a göre renk)
- [x] `flutter_map_marker_cluster` entegrasyonu
- [x] Bottom sheet inline `DraggableScrollableSheet` (spot_detail_sheet ayrı dosya değil)
- [x] Harita tile cache: `flutter_map_tile_caching` bağlandı
- [x] Mera verileri Drift'te cache'leniyor

**Çıktı:** Harita açılıyor, mera pinleri cluster'lanmış görünüyor ✓

---

### H4 — Mera Yönetimi ✅

#### Görevler
- [x] `add_spot_screen.dart` — mera ekleme formu (tur, açıklama, Supabase insert)
- [x] Mera düzenleme: sahip sheet → **Düzenle** → `/map/edit-spot` (`updateSpot`)
- [x] Gizlilik seçimi: public / friends / private / vip UI
- [x] Konum seçimi: GPS (`LocationService`) veya `pick_spot_location_screen`
- [x] Yol tarifi: `geo:` + Google Maps yedek (`url_launcher`)
- [x] Sheet butonları: **Balık Var! / Yol Tarifi / Düzenle (sahip)**
- [x] Harita FAB: **Konumum** + **Mera ekle**
- [x] **Mera favorileme:** `FavoriteRepository` + `favorite_provider.dart`; sheet header'da bookmark butonu; profil "Favori Meralarım" bölümü
- [x] **Bildirim deep-link:** `MapScreen(initialSpotId)` — bildirim tap'ında mera otomatik açılır
- [x] **Favori mera bildirimi:** Check-in'de `getUsersWhoFavorited` → favorileyen kullanıcılara bildirim

**Çıktı:** Mera CRUD, favorileme ve bildirim deep-link çalışıyor ✓ (Dükkan katmanı → H15.)

---

### H5 — Check-in Sistemi ✅

#### Görevler
- [x] `checkin_screen.dart` — check-in akış ekranı
- [x] Konum doğrulama: kullanıcı mera ± 500m'de mi?
- [x] Balık yoğunluğu seçimi UI (4 seviye)
- [x] Kalabalık seçimi UI (4 seviye)
- [x] `checkin_repository.dart` yazıldı
- [x] Supabase Realtime subscription: yeni check-in'leri dinle
- [x] Harita pin'i anlık güncelleniyor (Realtime)
- [x] Check-in veri yaşam süresi: 2 saat sonra soluk/azaltılmış görünüm
- [x] Fotoğraf yükleme ve EXIF doğrulama kaldırıldı (UX sadeleştirildi)

**Çıktı:** Check-in yapılınca haritada anlık görünüyor ✓

---

### H6 — EXIF Doğrulama & Oylama
**Hedef:** Güven sistemi aktif, sahte raporlar engelleniyor

**Durum:** ✅ Tamamlandı — Check-in fotoğraf yükleme ve EXIF doğrulama akışı kaldırıldı; oylama çalışıyor.

#### Görevler
- [x] `exif_helper.dart` yazıldı (balık günlüğü için kullanılıyor)
- [x] Supabase Edge Function: `exif-verify` yazıldı (balık günlüğü için; check-in akışından bağımsız)
- [x] Storage trigger: balık günlüğü fotoğrafları için (check-in fotoğrafı kaldırıldı)
- [x] `vote_widget.dart` — Doğru/Yanlış oy butonu
- [x] `checkin_repository.dart`'a vote fonksiyonu eklendi
- [ ] Oy sonucu: %70+ yanlış → check-in gizleniyor *(ileriye ertelendi)*
- [x] Check-in ekranından fotoğraf yükleme + EXIF doğrulama kaldırıldı (UX sadeleştirildi)

**Çıktı:** Oylama sistemi çalışıyor; check-in akışı sadeleştirildi ✓

---

## FAZ C — Günlük, Puan, Hava, Bildirim (H7–H10)

**Durum:** H7 ✅ H8 ✅ H9 ✅ tamamlandı; H10 🔄 kısmen tamamlandı (favori bildirim + deep-link çalışıyor; konum bazlı bildirim, sessiz mod, limit kalmış).

### H7 — Balık Günlüğü
**Hedef:** Balık kaydı eklenip görüntülenebiliyor

#### Görevler
- [ ] `local_fish_log.dart` ve Drift şeması oluşturuldu
- [ ] `fish_log_repository.dart` yazıldı
- [ ] `add_log_screen.dart` — kayıt formu
- [ ] Hava snapshot: kayıt anında cache'den hava verisi ekleniyor
- [ ] Fotoğraf yükleme: image_picker → WebP → Supabase Storage
- [ ] Gizli kayıt toggle'ı UI'a eklendi
- [ ] `log_list_screen.dart` — kayıt listesi
- [ ] Offline-first: Drift'e yaz, internet gelince sync
- [ ] `sync_queue.dart` — offline işlem kuyruğu
- [ ] `stats_screen.dart` — istatistik ekranı (toplam, tür, mera, grafik)

**Çıktı:** Günlük kaydı offline çalışıyor, sync ediliyor ✓

---

### H8 — Puan & Rütbe Sistemi ✅

#### Görevler
- [x] Edge Function: `score-calculator` yazıldı ve deploy edildi
- [x] DB trigger: checkin/vote/fish_log insert → score-calculator tetikle
- [x] `rank_screen.dart` — Genel / Haftalık / Bölge sekmeleri; **dikey liste** (podium kaldırıldı)
- [x] Top-3 için 🥇🥈🥉 madalya + altın/gümüş/bronz zemin rengi
- [x] Rütbe rozeti: profil ekranında `RankBadge`
- [x] `profile_screen.dart` — puan, rütbe, istatistik; "Favori Meralarım" bölümü (isSelf)
- [x] **Bug düzeltme:** `user_repository.dart` varsayılan rank `'bronz'` → `'acemi'`
- [ ] Edge Function: `shadow-point-calculator` yazıldı ve deploy edildi *(ileriye ertelendi)*
- [ ] VIP mera görünürlüğü: Usta+ rütbesine göre filtreleme *(ileriye ertelendi)*
- [ ] Mera Muhtarlığı: haftalık cron *(ileriye ertelendi)*

**Çıktı:** Sıralama ekranı çalışıyor, profil ekranı tamamlandı ✓

---

### H9 — Hava Durumu ✅

#### Görevler
- [x] Edge Function: `weather-cache` yazıldı ve deploy edildi
- [ ] Supabase cron job: her 4 saatte weather-cache tetikleniyor *(ileriye ertelendi)*
- [x] `weather_model.dart` ve `hourly_weather_model.dart` (cloudCover dahil) yazıldı
- [x] `weather_service.dart` — Open-Meteo forecast + marine API; `forecast_days=2`; `cloudcover` parametresi
- [x] Balıkçı dili çevirisi: 30 kural tablosu yazıldı (`FishingWeatherUtils`)
- [x] `weather_screen.dart` — 24 saatlik saatlik grafik (rüzgar hızı alt etiket)
- [x] Saat başı otomatik güncelleme (`_scheduleNextHourlyUpdate`); manuel yenileme kaldırıldı
- [x] Deniz metrikleri (dalga, SST, akıntı, bulutluluk) `_WeatherDetailGrid`'de `currentHour` ile
- [x] Hava verisi Drift'te cache'leniyor (offline)
- [x] `istanbul_weather_provider.dart` — saat başı kesin timer (30 dakika yerine)

**Çıktı:** 24 saatlik hava grafiği çalışıyor, saat başı otomatik güncelleniyor ✓

---

### H10 — Push Bildirim Sistemi 🔄

#### Görevler
- [x] Edge Function: `notification-sender` yazıldı ve deploy edildi
- [x] FCM token izin verildiğinde alınıp `users.fcm_token`'a yazılıyor
- [x] **Bildirim deep-link:** tap → `{"type":"checkin","spot_id":"..."}` JSON payload; `_navigateFromPayload` ile spot açılır
- [x] **Favori mera bildirimi:** `FavoriteRepository.getUsersWhoFavorited` → favorileyen kullanıcılara bildirim
- [x] `notification_list_screen.dart` — bildirim geçmişi + spot deep-link yönlendirme
- [x] `notification_settings_screen.dart` — her tür açık/kapalı
- [x] Konum tabanlı bildirim: `nearby-checkin-notifier` Edge Function; check-in sonrası 2km yarıçapındaki aktif kullanıcılara bildirim; favorileyen kullanıcılar duplicate önleme ile hariç tutuldu
- [ ] Gölge puan bildirimi: shadow-point-calculator'dan tetikleniyor *(ileriye ertelendi)*
- [x] Sabah 06:00 hava bildirimi: `morning-weather-push` Edge Function + `cron_morning_weather_push.sql` cron job (03:00 UTC = 06:00 İstanbul)
- [ ] Sezon hatırlatma: balık takvimi tablosundan tetikleniyor *(ileriye ertelendi)*
- [ ] Rütbe yükselme bildirimi: score-calculator'dan tetikleniyor *(ileriye ertelendi)*
- [x] Günlük 5 bildirim limiti kontrolü: `notification-sender`'da günlük 5 limit + `force` parametresi (sabah bildirimi sayılmaz)
- [x] Gece 23:00–07:00 sessiz mod: `notification-sender`'da `isSilentHours()` kontrolü, push atlanır in-app kayıt yapılır

**Çıktı:** Konum tabanlı bildirim + sabah hava push + günlük limit + sessiz mod ✓

---

## FAZ D — Offline & Motivasyon UI (H11–H13)

### H11 — Düğüm & Takım Rehberi ✅
**Hedef:** Rehber tamamen offline çalışıyor

#### Görevler
- [x] 30 düğüm için `knots_data.json` hazırlandı
- [ ] Lottie animasyon dosyaları oluşturuldu/temin edildi *(ileriye ertelendi — JSON adım gösterimi yeterli)*
- [x] JSON assets olarak projeye eklendi (`assets/knots/`, `assets/tackle/`)
- [x] `knots_screen.dart` — iki sekme: Düğümler (grid + filtre) + Takımlar (expandable liste)
- [x] `knot_detail_screen.dart` — adım adım gösterim + "Öğrendim" toggle (SharedPreferences)
- [x] `knot_filter_widget.dart` — tür + zorluk filtresi
- [x] Takım önerileri: `tackle_data.json` hazırlandı (8 senaryo: lüfer, çipura, levrek, istavrit, sazan, palamut, kalamar, surf)
- [x] `tackle_model.dart` yazıldı (`TackleModel`, `TackleItem`)
- [ ] Tamamen offline test edildi (uçak modu)

**Çıktı:** Rehber uçak modunda çalışıyor ✓

---

### H12 — Offline Harita İndirme 🔄
**Hedef:** Seçilen bölge haritası offline çalışıyor

#### Görevler
- [ ] `flutter_map_tile_caching` download manager entegrasyonu *(ileriye ertelendi — paket pubspec'te yok; H15'e alındı)*
- [ ] Haritada alan seçim arayüzü (dikdörtgen çizim) *(ileriye ertelendi)*
- [ ] Tahmini boyut hesaplama ve kullanıcıya gösterim *(ileriye ertelendi)*
- [ ] İndirme yöneticisi: ilerleme çubuğu, durdur, devam, sil *(ileriye ertelendi)*
- [ ] Depolama uyarısı UI *(ileriye ertelendi)*
- [x] Offline check-in kuyruğa ekleniyor (`SyncService.instance.enqueue`)
- [x] Bağlantı gelince otomatik sync tetikleniyor (`connectivity_plus` stream + 30 sn yedek poll)
- [x] Ağ durumu izleme: `connectivity_plus` + `connectivityProvider` (StreamProvider) + `isOnlineProvider`
- [x] Offline modda UI göstergesi: `MainShell`'de AnimatedContainer banner

**Çıktı (kısmi):** Offline check-in → kuyruğa → online olunca otomatik sync ✓

---

### H13 — Motivasyon UI Tamamlama ✅
**Hedef:** Tüm motivasyon akışı görsel olarak bağlandı

#### Görevler
- [x] VIP mera pin'leri altın renk, kilitli ikon (Usta öncesi) — `spot_marker.dart` `isLocked` parametresi; `map_screen.dart` `_fetchCurrentUserRank` ile rütbeye göre belirleniyor
- [x] Rütbe ilerleme çubuğu: profil ekranında görsel — `_RankProgress` widget (profile_screen.dart)
- [x] Muhtar rozeti: spot_detail_sheet'te gösterim — `_SpotSheetHeader` `hasMuhtar` parametresi
- [x] Gizlilik uyarısı: mera eklerken puan farkı açıklaması — `_PrivacyInfoBanner` (add_spot_screen.dart)
- [ ] "Gölge puan kazandın" animasyonu (Lottie) *(ertelendi — Lottie pubspec'te yok; H15'e alındı)*
- [x] Sürdürülebilirlik badge: profil + günlük listesinde — `♻️ Bırakıldı` rozeti (log_list_screen.dart); sürdürülebilirlik skoru (profile_screen.dart)
- [x] Boş ekran tasarımları: mera yok → `_EmptySheetHints`; günlük yok → emoji+CTA; bildirim yok → `_NotificationEmptyState` özel çizim
- [ ] Rütbe yükselme kutlama animasyonu *(ertelendi — Lottie pubspec'te yok; H15'e alındı)*

**Çıktı:** Motivasyon döngüsü görsel olarak bağlandı; animasyon görevleri H15'e alındı ✓

---

## FAZ E — Test, Polish & Launch (H14–H16)

### H14 — Kapsamlı Test 🔄
**Hedef:** Kararlı, hatasız uygulama

#### Görevler
- [x] KnotDetailScreen widget testleri (13 test): başlık, kategori, adımlar, zorluk yıldızları, Öğrendim toggle, SharedPreferences persistence
- [x] StatsScreen hesaplama unit testleri (17 test): toplam av, salınan balık, sürdürülebilirlik %, tür sıralaması
- [x] ResetPasswordScreen form validasyon widget testleri (7 test): boş alan, min uzunluk, şifre eşleşmesi, toggle görünürlük
- [x] Release build doğrulandı: `flutter build appbundle --release` → 49.5MB ✓
- [x] 171 otomatik test, tümü yeşil
- [ ] Tüm kullanıcı akışları uçtan uca test edildi *(manuel — cihaz gerektirir)*
- [ ] Offline → online geçiş senaryoları test edildi *(manuel)*
- [ ] Düşük ağ hızında test (throttling) *(manuel)*
- [ ] Farklı ekran boyutları test edildi *(manuel)*
- [ ] Edge case'ler: mera 500m dışında check-in, EXIF yok, oy eşitliği *(manuel)*
- [ ] Bellek sızıntısı kontrolü (Riverpod dispose) *(manuel)*
- [ ] Harita performansı: 500+ mera cluster testi *(manuel)*
- [ ] Supabase RLS politikaları test edildi *(manuel — Supabase dashboard)*
- [ ] Firebase bildirim tüm senaryolarda test edildi *(manuel — cihaz gerektirir)*

---

### H15 — UX Polish
**Hedef:** Kullanıcı deneyimi yayına hazır

#### Görevler
- [ ] Loading state'leri her ekranda tutarlı (shimmer veya skeleton) *(shimmer paketi pubspec'te yok; H16'ya ertelendi)*
- [x] Hata mesajları kullanıcı dostu Türkçe — tüm ekranlarda Türkçe hata metni mevcut
- [x] Sayfa geçiş animasyonları (go_router transitions) — fade+slide 250ms, tüm push route'lara uygulandı
- [x] Haptic feedback: check-in ✓, mera kaydet ✓, düğüm öğrendim ✓, profil yenile ✓
- [x] Dark mode desteği — uygulama baştan koyu tema (AppColors.navy)
- [x] Türkçe karakter sorunu kontrolü — font varsayılanı Flutter; Türkçe özel karakter hatalar önceki sprint'lerde düzeltildi
- [x] İnternet yok banner'ı — MainShell AnimatedContainer offline banner
- [x] Pull-to-refresh tüm liste ekranlarında: bildirim ✓, fish-log ✓, rank ✓, profil ✓, hava ✓
- [x] **Harita — dükkan katmanı:** `seed_shops.sql` (15 kayıt), `ShopModel` + `ShopRepository`, `MapScreen`’de turuncu `_ShopPin` + `_ShopDetailSheet` modal

---

### H16 — Launch Hazırlık
**Hedef:** Play Store beta'da

#### Görevler
- [ ] Google Play Console hesabı açıldı (25$ tek seferlik)
- [x] App icon oluşturuldu — `assets/icon/app_icon.png`, `flutter_launcher_icons` ile tüm boyutlar üretildi
- [x] Splash screen — `#0A2A2F` renk tabanlı, `#132236` adaptive icon background
- [x] Play Store açıklama metni yazıldı (Türkçe) — `docs/play_store_listing.md`
- [ ] En az 5 ekran görüntüsü hazırlandı
- [ ] Gizlilik politikası sayfası yayında (web URL)
- [x] `flutter build appbundle --release` başarılı — 49.4MB AAB (`build/app/outputs/bundle/release/app-release.aab`)
- [x] İmzalama: `android/app/build.gradle.kts` signing config + `key.properties.template` hazır (keystore oluşturmak kullanıcıya kalıyor)
- [ ] Play Store'a APK yüklendi
- [ ] İç test (5 kişi) tamamlandı
- [ ] Beta kanalına alındı

**Çıktı:** Play Store'da beta sürümü yayında 🚀

---

## Hızlı Referans — Günlük Çalışma Akışı

```
1. Bu dosyayı aç → hangi sprint'tesin, hangi görev sırada?
2. Görevi başlat → ARCHITECTURE.md'e bak (hangi servis, hangi pattern?)
3. MVP_PLAN.md'e bak → özelliğin teknik detayı nedir?
4. Kodu yaz → test et → commit
5. Görevi ✅ işaretle → bir sonrakine geç
```

## Commit Mesaj Formatı

```
feat(map): mera ekleme formu tamamlandı
fix(checkin): 500m yarıçap kontrolü düzeltildi
feat(auth): Google OAuth entegrasyonu
refactor(score): puan hesaplama Edge Function optimize edildi
docs: SPRINT.md H3 görevleri güncellendi
```
