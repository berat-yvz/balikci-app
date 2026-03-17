# Balıkçı Super App — 16 Haftalık Sprint Planı

> Her sprint başında bu dosyayı güncelle.
> Tamamlanan görevleri ✅, devam edenleri 🔄, bekleyenleri ⏳ ile işaretle.

---

## Sprint Özeti

| Faz | Haftalar | Odak | Durum |
|-----|---------|------|-------|
| Faz A | H1–H2 | Kurulum & Auth | 🔄 |
| Faz B | H3–H6 | Harita & Check-in Çekirdeği | ⏳ |
| Faz C | H7–H10 | Günlük, Puan, Hava, Bildirim | ⏳ |
| Faz D | H11–H13 | Offline & Motivasyon UI | ⏳ |
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
- [ ] `auth_repository.dart` yazıldı (signUp, signIn, signOut, getUser)
- [ ] `auth_provider.dart` Riverpod provider yazıldı
- [ ] `login_screen.dart` — e-posta + şifre formu
- [ ] `register_screen.dart` — kayıt formu, validasyon
- [ ] `auth_gate.dart` — oturum kontrolü, yönlendirme
- [ ] `onboarding_screen.dart` — 3 adımlı akış
- [ ] `step_location.dart` — konum izni (geolocator)
- [ ] `step_notification.dart` — bildirim izni (FCM)
- [ ] `step_first_spot.dart` — ilk mera CTA
- [ ] go_router guard: giriş yapılmamışsa `/login`'e yönlendir
- [ ] JWT token Drift'te saklanıyor, offline oturum çalışıyor
- [ ] Splash ekranı (2 sn, logo)

**Çıktı:** Kullanıcı kayıt, giriş, onboarding akışını tamamlayabiliyor ✓

---

## FAZ B — Harita & Check-in Çekirdeği (H3–H6)

### H3 — Harita Temeli
**Hedef:** Harita açılıyor, meralar görünüyor

#### Görevler
- [ ] `map_screen.dart` — FlutterMap widget entegrasyonu
- [ ] OpenStreetMap tile provider bağlandı
- [ ] `spot_repository.dart` yazıldı (getSpots, addSpot, updateSpot)
- [ ] `spot_model.dart` ve Drift şeması oluşturuldu
- [ ] Mera pinleri haritada gösteriliyor (privacy_level'a göre renk)
- [ ] `flutter_map_marker_cluster` entegrasyonu
- [ ] `spot_detail_sheet.dart` — pin'e tıklayınca alt sheet açılıyor
- [ ] Harita tile cache: `flutter_map_tile_caching` bağlandı
- [ ] Mera verileri Drift'te cache'leniyor

**Çıktı:** Harita açılıyor, mera pinleri cluster'lanmış görünüyor ✓

---

### H4 — Mera Yönetimi
**Hedef:** Kullanıcı mera ekleyip düzenleyebiliyor

#### Görevler
- [ ] `add_spot_screen.dart` — mera ekleme formu
- [ ] Gizlilik seçimi: public / friends / private / vip UI
- [ ] Konum seçimi: haritadan pin bırakma veya GPS
- [ ] Dükkan JSON verisi hazırlandı (10+ dükkan)
- [ ] Dükkan verileri Supabase'e import edildi
- [ ] Dükkan pinleri haritada farklı ikonla gösteriliyor
- [ ] Yol tarifi: `geo:lat,lng?q=label` URL launcher entegrasyonu
- [ ] `spot_detail_sheet.dart`'a "Yol Tarifi Al" butonu eklendi

**Çıktı:** Mera eklenip haritada görünüyor, yol tarifi çalışıyor ✓

---

### H5 — Check-in Sistemi
**Hedef:** Anlık check-in çalışıyor, harita gerçek zamanlı güncelleniyor

#### Görevler
- [ ] `checkin_screen.dart` — check-in akış ekranı
- [ ] Konum doğrulama: kullanıcı mera ± 500m'de mi?
- [ ] Balık yoğunluğu seçimi UI (4 seviye)
- [ ] Kalabalık seçimi UI (4 seviye)
- [ ] `checkin_repository.dart` yazıldı
- [ ] Supabase Realtime subscription: yeni check-in'leri dinle
- [ ] Harita pin'i anlık güncelleniyor (Realtime)
- [ ] Check-in veri yaşam süresi: 2 saat sonra `is_active = false`
- [ ] Eski check-in pin'leri haritada solar (opacity azalır)

**Çıktı:** Check-in yapılınca haritada anlık görünüyor ✓

---

### H6 — EXIF Doğrulama & Oylama
**Hedef:** Güven sistemi aktif, sahte raporlar engelleniyor

#### Görevler
- [ ] `exif_helper.dart` yazıldı (native_exif ile GPS + timestamp oku)
- [ ] Supabase Edge Function: `exif-verify` yazıldı ve deploy edildi
- [ ] Storage trigger: fotoğraf yüklenince Edge Function tetikleniyor
- [ ] `vote_widget.dart` — Doğru/Yanlış oy butonu
- [ ] `checkin_repository.dart`'a vote fonksiyonu eklendi
- [ ] Oy sonucu: %70+ yanlış → check-in gizleniyor
- [ ] Doğrulanmış check-in rozeti UI'a eklendi

**Çıktı:** EXIF doğrulama ve oylama sistemi çalışıyor ✓

---

## FAZ C — Günlük, Puan, Hava, Bildirim (H7–H10)

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

### H8 — Puan & Rütbe Sistemi
**Hedef:** Puan kazanılıyor, rütbe ilerliyor

#### Görevler
- [ ] Edge Function: `score-calculator` yazıldı ve deploy edildi
- [ ] DB trigger: checkin/vote/fish_log insert → score-calculator tetikle
- [ ] Edge Function: `shadow-point-calculator` yazıldı ve deploy edildi
- [ ] `rank_screen.dart` — rütbe ilerleme ekranı
- [ ] Rütbe rozeti: profil + harita pin'de gösterim
- [ ] VIP mera görünürlüğü: Usta+ rütbesine göre filtreleme
- [ ] `leaderboard_screen.dart` — liderlik tablosu (bölge bazlı)
- [ ] Mera Muhtarlığı: haftalık cron ile güncellenen muhtar rozeti
- [ ] `profile_screen.dart` — puan, rütbe, istatistik

**Çıktı:** Puan sistemi çalışıyor, rütbe ilerliyor ✓

---

### H9 — Hava Durumu
**Hedef:** Balıkçı dilinde hava kartı çalışıyor

#### Görevler
- [ ] Edge Function: `weather-cache` yazıldı ve deploy edildi
- [ ] Supabase cron job: her 4 saatte weather-cache tetikleniyor
- [ ] `weather_model.dart` yazıldı
- [ ] `weather_service.dart` — en yakın bölge verisini çek
- [ ] Balıkçı dili çevirisi: 30 kural tablosu yazıldı
- [ ] `weather_card_widget.dart` — ana ekranda hava kartı
- [ ] `weather_screen.dart` — detaylı hava ekranı (7 günlük)
- [ ] Hava verisi Drift'te cache'leniyor (offline)

**Çıktı:** Hava kartı açılıyor, balıkçı dili yorumu gösteriliyor ✓

---

### H10 — Push Bildirim Sistemi
**Hedef:** Tüm bildirim türleri çalışıyor

#### Görevler
- [ ] Edge Function: `notification-sender` yazıldı ve deploy edildi
- [ ] FCM token kullanıcı kaydında alınıp Supabase'e yazılıyor
- [ ] Konum tabanlı bildirim: 2km'de check-in → yakın kullanıcılara gönder
- [ ] Favori mera bildirimi: favorilenen meraya check-in → bildirim
- [ ] Gölge puan bildirimi: shadow-point-calculator'dan tetikleniyor
- [ ] Sabah 06:00 hava bildirimi: cron job
- [ ] Sezon hatırlatma: balık takvimi tablosundan tetikleniyor
- [ ] Rütbe yükselme bildirimi: score-calculator'dan tetikleniyor
- [ ] Günlük 5 bildirim limiti kontrolü
- [ ] Gece 23:00–07:00 sessiz mod
- [ ] `notification_settings_screen.dart` — her tür açık/kapalı
- [ ] `notification_list_screen.dart` — bildirim geçmişi

**Çıktı:** Tüm bildirim türleri çalışıyor, limit ve sessiz mod aktif ✓

---

## FAZ D — Offline & Motivasyon UI (H11–H13)

### H11 — Düğüm & Takım Rehberi
**Hedef:** Rehber tamamen offline çalışıyor

#### Görevler
- [ ] 30 düğüm için `knots_data.json` hazırlandı
- [ ] Lottie animasyon dosyaları oluşturuldu/temin edildi
- [ ] JSON assets olarak projeye eklendi
- [ ] `knots_screen.dart` — liste + filtreler
- [ ] `knot_detail_screen.dart` — adım adım animasyonlu gösterim
- [ ] `knot_filter_widget.dart` — tür + zorluk filtresi
- [ ] Takım önerileri: `tackle_data.json` hazırlandı
- [ ] Tamamen offline test edildi (uçak modu)

**Çıktı:** Rehber uçak modunda çalışıyor ✓

---

### H12 — Offline Harita İndirme
**Hedef:** Seçilen bölge haritası offline çalışıyor

#### Görevler
- [ ] `flutter_map_tile_caching` download manager entegrasyonu
- [ ] Haritada alan seçim arayüzü (dikdörtgen çizim)
- [ ] Tahmini boyut hesaplama ve kullanıcıya gösterim
- [ ] İndirme yöneticisi: ilerleme çubuğu, durdur, devam, sil
- [ ] Depolama uyarısı UI
- [ ] Offline check-in kuyruğa ekleniyor
- [ ] Bağlantı gelince otomatik sync tetikleniyor
- [ ] `connectivity_provider.dart` — ağ durumu izleme
- [ ] Offline modda UI göstergesi (banner)

**Çıktı:** Seçilen bölge offline çalışıyor, check-in sync oluyor ✓

---

### H13 — Motivasyon UI Tamamlama
**Hedef:** Tüm motivasyon akışı görsel olarak bağlandı

#### Görevler
- [ ] VIP mera pin'leri altın renk, kilitli ikon (Usta öncesi)
- [ ] Rütbe ilerleme çubuğu: profil ekranında görsel
- [ ] Muhtar rozeti: spot_detail_sheet'te gösterim
- [ ] Gizlilik uyarısı: mera eklerken puan farkı açıklaması
- [ ] "Gölge puan kazandın" animasyonu (Lottie)
- [ ] Sürdürülebilirlik badge: profil + günlük listesinde
- [ ] Boş ekran tasarımları: mera yok, günlük yok, bildirim yok
- [ ] Rütbe yükselme kutlama animasyonu

**Çıktı:** Tüm motivasyon döngüsü görsel olarak eksiksiz ✓

---

## FAZ E — Test, Polish & Launch (H14–H16)

### H14 — Kapsamlı Test
**Hedef:** Kararlı, hatasız uygulama

#### Görevler
- [ ] Tüm kullanıcı akışları uçtan uca test edildi
- [ ] Offline → online geçiş senaryoları test edildi
- [ ] Düşük ağ hızında test (throttling)
- [ ] Farklı ekran boyutları test edildi
- [ ] Edge case'ler: mera 500m dışında check-in, EXIF yok, oy eşitliği
- [ ] Bellek sızıntısı kontrolü (Riverpod dispose)
- [ ] Harita performansı: 500+ mera cluster testi
- [ ] Supabase RLS politikaları test edildi
- [ ] Firebase bildirim tüm senaryolarda test edildi

---

### H15 — UX Polish
**Hedef:** Kullanıcı deneyimi yayına hazır

#### Görevler
- [ ] Loading state'leri her ekranda tutarlı (shimmer veya skeleton)
- [ ] Hata mesajları kullanıcı dostu Türkçe
- [ ] Sayfa geçiş animasyonları (go_router transitions)
- [ ] Haptic feedback: butonlarda, başarı anlarında
- [ ] Dark mode desteği
- [ ] Türkçe karakter sorunu kontrolü (font)
- [ ] İnternet yok banner'ı
- [ ] Pull-to-refresh tüm liste ekranlarında

---

### H16 — Launch Hazırlık
**Hedef:** Play Store beta'da

#### Görevler
- [ ] Google Play Console hesabı açıldı (25$ tek seferlik)
- [ ] App icon oluşturuldu (1024x1024 PNG)
- [ ] Splash screen tasarlandı
- [ ] Play Store açıklama metni yazıldı (Türkçe)
- [ ] En az 5 ekran görüntüsü hazırlandı
- [ ] Gizlilik politikası sayfası yayında (web URL)
- [ ] `flutter build appbundle --release` başarılı
- [ ] İmzalama: keystore oluşturuldu, güvenli saklandı
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
