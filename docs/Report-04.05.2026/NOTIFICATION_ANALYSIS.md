# Bildirim (Notification) Mekanizması ve Altyapı Analizi — Kapsamlı Rapor

> **Tarih:** 04 Mayıs 2026  
> **Analiz Edilen Dosyalar:** `notification_service.dart`, `notification_repository.dart`, `user_repository.dart`, `notification_list_screen.dart`, `notification_routing.dart`, `notification-sender/index.ts`, `morning-weather-push/index.ts`, `season-reminder-push/index.ts`, `nearby-checkin-notifier/index.ts`, `cron_morning_weather_push.sql`, `cron_season_reminder_push.sql`, `ARCHITECTURE.md`, `MVP_PLAN.md`  
> **Kapsam:** Kod değişikliği yok — salt analiz ve öneri

---

## 1. Backend ve Teslimat Altyapısı (Infrastructure)

### 1.1 Token Yönetimi

**Mevcut mimari:** FCM token'lar `users.fcm_token TEXT` sütununda saklanıyor. Token alma ve Supabase'e yazma akışı şu şekilde işliyor:

```
Uygulama açılışı
    → NotificationService.initialize()
    → İzin zaten verilmişse: syncFcmToken() → FCM.getToken() → UserRepository.updateFcmToken()
    → Token yenilendiğinde: _messaging.onTokenRefresh → _saveTokenToSupabase()
```

**Güçlü yönler:**
- `onTokenRefresh` dinleyici aktif — FCM token rotasyonu otomatik yakalanıyor ✅
- `syncFcmToken` uygulama başlangıcında çağrılıyor — yeniden yüklemelerde senkron sağlanıyor ✅
- FCM token yoksa `notification-sender` bildirim DB'ye in-app kaydı düşüp push atlamıyor; sessiz başarısızlık doğru yönetiliyor ✅

**Kritik Riskler:**

**1 — Hayalet Bildirim (Stale Token) Riski:**  
Kullanıcı çıkış yaptığında (`signOut`) `users.fcm_token` sütunu **null'a çekilmiyor.** `_saveTokenToSupabase` sadece token yenilenince veya uygulama açılınca çalışıyor; çıkış anında temizlik yapan bir çağrı yok. Sonuç:
- Kullanıcı A çıkış yapar → başka biri aynı cihazdan A'nın hesabına **girmeden** aynı uygulamanın yeni kurulumunu yapar → A'nın eski token'ı hâlâ DB'de → A'ya ait olmayan bir cihaza push gidebilir.
- Bu senaryo nadir ama KVKK/gizlilik açısından risk taşır.

**Öneri:** `AuthRepository.signOut()` veya auth state değişiminde (oturum kapandığında) `users.fcm_token = null` UPDATE çağrısı eklenmelidir.

**2 — Çok Cihaz Desteği Yok:**  
`fcm_token` tek bir TEXT sütunu; kullanıcının tablet + telefonu varsa son açılan cihazın token'ı kazanır. Eski cihaza bildirim gitmiyor. Bu şu anki hedef kitle için kabul edilebilir ama ileride `fcm_tokens TEXT[]` (dizi) veya ayrı tablo yaklaşımı gerekebilir.

---

### 1.2 Tetikleyiciler — pg_cron ve Performans Analizi

Sistemde iki `pg_cron` zamanlanmış görevi var:

| Cron Job | Zamanlama | Hedef |
|----------|-----------|-------|
| `morning-weather-push` | `0 3 * * *` (06:00 İstanbul) | Son 30 günde aktif kullanıcılara sabah hava bildirimi |
| `season-reminder-push` | `0 7 * * *` (10:00 İstanbul) | Aktif balık sezonu açılış hatırlatmaları |

**Mimari Pattern (Doğru kurgu):** Her iki cron job da `pg_net.http_post` ile Edge Function'ı tetikliyor; gerçek mantık Edge Function içinde. Bu, pg_cron işini (HTTP tetiklemek) Edge Function işinden (iş mantığı, push gönderme) ayırıyor — doğru tasarım ✅

**Morning Weather Push Analizi:**

```typescript
// morning-weather-push/index.ts — kritik bölümler
const { data: activeUsers } = await supabase
  .from('checkins')
  .select('user_id')
  .gte('created_at', since30d)
  .limit(1000)   // ← En fazla 1000 satır çekiyor
```

**Sorun 1 — Limit Aşımı:** Aktif kullanıcı tespiti için son 30 gündeki check-in satırlarından `user_id` çekiliyor; ancak `.limit(1000)` koyulmuş. Eğer son 30 günde 1000'den fazla check-in varsa (ki aktif bir uygulama için bu düşük bir eşik), bazı kullanıcılar tespit edilemiyor. `DISTINCT user_id` veya RPC kullanmak daha doğru olur.

**Sorun 2 — weather_cache'de Istanbul Sabit Kaydı:** Hava özetini `region_key = 'istanbul'` ile arıyor. Bu kaydın var olmaması veya güncellenmemiş olması durumunda `'Bugün hava durumunu kontrol et 🎣'` fallback mesajı gönderiliyor — zararsız ama ideal değil.

**Sorun 3 — Batch Boyutu Makul:** 50'şerli batch ile `notification-sender` çağrılıyor (`Promise.allSettled`). 1000 kullanıcı için 20 tur = 20 × 50 = 1000 fetch. Supabase Edge Function varsayılan timeout 2 dakika (120 saniye). Her `notification-sender` çağrısı ~1-2 sn alıyorsa 20 tur × 50 paralel = yaklaşık 40-60 saniye sürer. 150 saniye limitine yaklaşık yaklaşıyor. 2000+ aktif kullanıcıda timeout riski başlar.

**Season Reminder Push Analizi:**

Bu fonksiyon çok daha iyi kurgulanmış:
- `fish_season_push_log` ile yıl bazlı idempotency sağlanmış — aynı sezon bildirimi iki kez gitmiyor ✅
- UNIQUE kısıtı ihlali (kod `23505`) sessizce atlanıyor ✅
- Notification-sender HTTP hatası durumunda push_log kaydı silinerek retry kapısı açık bırakılıyor ✅
- 40'lık batch boyutu kullanılıyor ✅

**Sorun:** Sezon bildirimlerinde de aktif kullanıcı tespiti için `.limit(2000)` var. Bu daha büyük ama yine de katı bir üst sınır.

**Nearby Checkin Notifier Analizi:**

Her check-in anında Flutter istemcisi bu Edge Function'ı çağırıyor. İçeride:
- Son 24 saatte check-in yapan kullanıcıların meralarını çekiyor (`.limit(200)`)
- 2km yarıçapı Haversine ile hesaplanıyor
- Favori listesi ile kesişimi çıkarıyor (çift bildirim önleme) ✅
- `notification_settings.checkin_nearby` ayarına saygı gösteriyor ✅

**Sorun — İstemci Tarafı Çağrı Riski:** Bu Edge Function Flutter'dan `unawaited()` ile çağrılıyor. Ağ kesintisinde sessizce düşüyor. Bu kasıtlı bir tasarım kararı (UX'i engellememek için) ve doğru; ancak kritik bildirimlerde (favori mera sahibi) bu "fire-and-forget" yaklaşımı bazı bildirimlerin hiç gitmemesine neden olabilir. Favoriye bildirim ayrıca Flutter istemcisinde gönderildiği için bu risk azaltılmış ✅

---

### 1.3 Edge Function Timeout Riski

| Senaryo | Tahmini Kullanıcı | Beklenen Süre | Risk |
|---------|-------------------|---------------|------|
| MVP (<500 aktif kullanıcı) | ~500 | ~15-30 sn | ✅ Güvenli |
| Büyüme Fazı (1000-2000) | ~2000 | ~60-90 sn | ⚠️ Sınırda |
| Ölçek Fazı (5000+) | ~5000+ | >120 sn | ❌ Timeout |

**Öneri (Ölçek için):**  
MVP kapsamında kritik değil. Büyüme fazına geçilince şu iki yaklaşımdan biri uygulanmalı:
1. **Fan-out pattern:** `morning-weather-push` toplu kullanıcı listesi çıkartır, ardından Supabase Queue (pg_queue) veya Redis'e yazar; ayrı bir Edge Function pop ederek gönderir.
2. **Mevcut yapıda optimize:** Aktif kullanıcı listesini `notification-sender` yerine doğrudan FCM'in Multicast API'si ile tek seferde göndermek (FCM Multicast, 500 token'a kadar tek HTTP çağrısı destekler).

---

## 2. Frekans Kontrolü ve Anti-Spam (Yorgunluk Koruması)

### 2.1 Mevcut Rate Limiting Analizi

`notification-sender/index.ts` içindeki limit mekanizması:

```typescript
// Günlük 5 bildirim limiti
if (!force) {
  const { count } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user_id)
    .gte('created_at', todayStart.toISOString())

  if ((count ?? 0) >= 5) {
    return { success: false, reason: 'daily_limit_reached' }
  }
}
```

**Güçlü yönler:**
- Günlük 5 bildirim üst sınırı var ✅
- `force: true` parametresi ile kritik bildirimler (rütbe yükselmesi, sabah hava) limiti aşabiliyor ✅
- 23:00–07:00 İstanbul saati sessiz mod uygulanıyor ✅

**Eksiklikler:**

**1 — "force" Bildirimleri Sınırsız:**  
`force: true` ile atılan bildirimler günlük limiti saymıyor. `morning-weather-push` VE `season-reminder-push` ikisi de `force: true` kullanıyor. Teorik olarak hem sabah hava bildirimi hem aynı gün sezon hatırlatması hem de rütbe bildirimi gelebilir — kullanıcı 3+ `force` bildirim alabilir. Hedef kitle için bu bile yüksek.

**Öneri:** `force` bildirimleri kendi kategorisinde ayrı bir sayaçla sınırlandırılmalı. Örneğin: `force_count_today <= 2` kontrolü.

**2 — Limit Hesabı `notifications` Tablosundan:**  
Günlük limit, `notifications` tablosuna insert edilen satır sayısına göre hesaplanıyor. Eğer Edge Function bir hata ile `notifications` INSERT'ini atlayıp push atarsa, limit sayacı düzgün çalışmaz. Bu kod incelemesinde FCM başarısız olsa bile `notifications` INSERT'i gerçekleştiriyor (doğru) ama INSERT başarısız olursa push gitmiş ama sayılmamış olur.

**3 — Cihaz Değiştirince Sıfırlama Yok:**  
Limit `user_id` bazlı ve `notifications` tablosuna bağlı — cihaz değişse bile geçerli kalıyor. Bu istenen davranış; kullanıcı bazlı limit doğru ✅

---

### 2.2 Kategori Yönetimi (Subscription Topics)

Sistem `notification_settings` adında bir tablo kullanıyor. Kod incelemesinde aşağıdaki sütunlar referans ediliyor:

| Sütun | Kontrol Edildiği Yer | Anlamı |
|-------|----------------------|--------|
| `weather_morning` | `morning-weather-push` | Sabah hava bildirimi aç/kapat |
| `season_reminder` | `season-reminder-push` | Sezon hatırlatması aç/kapat |
| `checkin_nearby` | `nearby-checkin-notifier` | Yakın check-in bildirimi aç/kapat |

**Önemli Bulgu — Opt-out Mantığı:**  
`morning-weather-push` ve `nearby-checkin-notifier`'da varsayılan davranış **opt-out** (ayar yoksa bildirim gönder). `notification_settings` tablosunda kaydı olmayan kullanıcıya bildirim gidiyor. Bu, yeni kullanıcılar için kasıtsız spam riski taşır; ancak yeni kullanıcıların onboarding'de izin verdiği varsayılıyorsa mantıklı.

**Eksik Kategoriler:**  
Kodda kontrol edilen ama `notification_settings`'e net olarak yansımayan kategoriler:

| Bildirim Türü | Settings Kontrolü |
|---------------|-------------------|
| `checkin` (mera sahibine) | ❌ Kontrol edilmiyor |
| `checkin` (favori mera sahibine) | ❌ Kontrol edilmiyor |
| `vote` (oy bildirimi) | ❌ Kontrol edilmiyor |
| `rank_up` (rütbe yükselmesi) | ❌ Kontrol edilmiyor |
| `shadow_point` | ❌ Edge Function yok |

Kullanıcı "favori merama check-in bildirimini kapat" seçeneği yapamıyor. Bu, hedef kitle için kritik bir kontrol eksikliği.

**Öneri:** `notification_settings` tablosuna şu sütunlar eklenmeli:
```sql
checkin_spot_owner   BOOLEAN DEFAULT true,  -- merana birisi check-in yaptı
checkin_favorite     BOOLEAN DEFAULT true,  -- favorin merada balık var
vote_received        BOOLEAN DEFAULT true,  -- oylamayla ilgili bildirim
rank_up              BOOLEAN DEFAULT true   -- rütbe yükselmesi
```

---

## 3. 45+ Yaş Amca İletişim Stratejisi ve UI/UX

### 3.1 Bildirim Başlıkları ve İçerik Analizi

Sistemde kullanılan mevcut bildirim metinleri:

| Kaynak | Başlık | İçerik | Değerlendirme |
|--------|--------|--------|---------------|
| `morning-weather-push` | `☀️ Günaydın Balıkçı!` | `{fishing_summary}\n{sıcaklık} {rüzgar}` | ✅ Doğal, sıcak, anlaşılır |
| `season-reminder-push` | `📅 Sezon hatırlatması` | `{tür} sezonu X gün sonra açılıyor. Hazırlan! 🎣` | ✅ Net, pratik |
| `nearby-checkin-notifier` | `🐟 Balık var!` | `{mera_adı} yakınında check-in yapıldı.` | ⚠️ Biraz teknik |
| `checkin_screen.dart` (mera sahibi) | `🎣 Meranızda Balık Var!` | `{mera_adı} merasında yeni bildirim geldi.` | ✅ Anlaşılır |
| `checkin_screen.dart` (favori sahip) | `🎣 Favori Meranızda Balık Var!` | `{mera_adı} merasında balık bildirimi geldi.` | ✅ Anlaşılır |
| `score-calculator` (rütbe) | `🏆 Tebrikler!` | `Yeni rütben: {rütbe_adı}` | ⚠️ Yetersiz heyecan |

**Detaylı İçerik Önerileri:**

**A — "Yakınında Balık Var" Bildirimi:**
```
❌ Mevcut: "🐟 Balık var! — Sirkeci İskelesi yakınında check-in yapıldı."
✅ Öneri:  "🎣 Yakında balık var! — Sirkeci İskelesi'nde balıkçılar var. 
            Ne bekliyorsun Reis?"
```

**B — Rütbe Yükselmesi Bildirimi:**
```
❌ Mevcut: "🏆 Tebrikler! — Yeni rütben: Olta Kurdu"
✅ Öneri:  "🏆 Bravo Reis! Artık OLTA KURDUSU'sun!
            Arkadaşlarının gizli meraları artık senin için açık!"
```
Kazandığı somut ayrıcalığı hemen push metninde söyle. 45+ yaş kitlesi "bunun ne işe yaradığını" anında görmek ister.

**C — Sabah Hava Bildirimi:**
```
✅ Mevcut zaten iyi: "☀️ Günaydın Balıkçı! — Deniz sakin, ideal gün ✓  🌡️ 18°C  💨 12 km/s"
💡 Geliştirilmiş: Hava iyiyse "BURAYA ÇIKMA" veya "MÜKEMMEL GÜN" vurgusu ekle
"☀️ Günaydın! Bugün deniz harika — ÇIKMAK İÇİN MÜKEMMEL GÜN! 🎣"
```

**D — Sezon Hatırlatması:**
```
✅ Mevcut: "📅 Sezon hatırlatması — Lüfer sezonu 7 gün sonra açılıyor. Hazırlan! 🎣"
💡 Geliştirilmiş: "📅 Lüfer geliyor Reis! 7 gün sonra sezon açılıyor.
                   Oltanı hazırla! 🎣"
```
"Reis" hitabı hedef kitle için çok doğru; saygı ve gizli bir övgü içeriyor.

---

### 3.2 Deep Linking — Yönlendirme Mekanizması Analizi

Sistemde iki farklı bildirim yönlendirme noktası var:

**A — FCM Push Tıklaması (`notification_service.dart`):**

```dart
String _routeForType(String? type) => switch (type?.toLowerCase()) {
  'checkin' => AppRoutes.home,     // harita (mera ile birlikte)
  'vote'    => AppRoutes.home,     // harita
  'rank'    => AppRoutes.rank,     // sıralama sekmesi
  'rank_up' => AppRoutes.rank,     // sıralama sekmesi
  'follow'  => AppRoutes.profile,  // profil
  'fish_log'=> AppRoutes.fishLog,  // balık günlüğü
  'season_reminder' => AppRoutes.weather, // hava durumu sekmesi
  _ => AppRoutes.home,
};
```

**B — In-App Bildirim Listesinden Tıklama (`notification_list_screen.dart`):**

```dart
void _navigateForNotification(GoRouter router, NotificationModel n) {
  checkin / vote  → harita + spot_id (mera sheet açılır)
  rank            → sıralama sekmesi
  follow          → karşı kullanıcı profili
  season          → hava durumu sekmesi
  diğerleri       → ana sayfa
}
```

**Değerlendirme:**

✅ **Doğru çalışanlar:**
- `checkin` / `vote` → `spot_id` ile haritada mera sheet'i açılıyor — mükemmel UX
- `rank_up` → Sıralama sekmesi
- `season_reminder` → Hava durumu sekmesi (sezon için mantıklı)
- `follow` → Karşı profil (profil ID ile tam yönlendirme)

⚠️ **Eksiklikler:**

**1 — `morning_weather` tipi yönlendirilmiyor:**  
`weather_morning` tipindeki push bildirimine tıklanınca `_routeForType` `switch` içinde bu tip yok — `default: AppRoutes.home` devreye giriyor ve **ana sayfaya (harita)** götürüyor. Kullanıcı sabah hava bildirimini tıklıyor, haritaya gidiyor. Mantıklı değil. `'weather_morning' => AppRoutes.weather` eklenmelidir.

**2 — `rank_up` bildirimi profil yerine sıralamaya götürüyor:**  
Kullanıcı yeni rütbesini aldığında sıralama sayfasına gidiyor. İdeal olan kendi profil sayfasına gidip yeni rozeti görmesi. `'rank_up' => AppRoutes.profile` daha iyi UX sağlar.

**3 — In-app bildirim listesinde `weather_morning` yönlendirmesi eksik:**  
`notification_list_screen.dart`'taki `_navigateForNotification` switch'inde `weather` / `weather_morning` tipi yok; `else` bloğuyla ana sayfaya düşüyor.

**4 — Uygulama kapalıyken "terminated" push durumu:**  
`NotificationService.initialize()` içinde `getInitialMessage()` ile yakalanıyor ve `_handleMessage(message)` çağrılıyor. Bu doğru ✅. Ancak `addPostFrameCallback` ile wrapped; eğer router henüz hazır değilse `appNavigatorKey.currentContext == null` olup navigate edilemiyor. Bu ince bir race condition.

---

### 3.3 Bildirim Listesi UI Analizi

`NotificationListScreen` üç durumu işliyor: loading, error, data. Temel UX çalışıyor. Gözlemler:

**İyi yönler:**
- Okunmamış bildirimler altın renkli kenarlık + nokta ile görselleştiriliyor ✅
- Tarih "3 dk önce", "2 saat önce" formatında — hedef kitle için anlaşılır ✅
- "Tümünü Oku" butonu var ✅
- Çeken yenile (pull-to-refresh) mevcut ✅

**Eksiklikler:**
- `_iconForType` Türkçe bildirim tiplerine bakıyor (`contains('checkin')`) ama `fish_log` ve `rank` için emoji var, `weather_morning` için yok — `🔔` varsayılanına düşüyor.
- Bildirim listesi sadece `read == false` filtreliyor. Okunmuş bildirimlere ulaşmanın yolu yok. Bir "Geçmiş" sekmesi veya "tüm bildirimleri göster" toggle'ı düşünülebilir.
- Boş durum metni "Yeni gelişmeleri kaçırmamak için takip etmeye devam et" — takip sistemini bilmeyen hedef kitle için belirsiz.  
  **Öneri:** "Meralara bildirim yaptıkça burada göreceksin 🎣"

---

## 4. Özet — Teknik Öncelik Sıralaması

| Öncelik | Konu | Etki | Aciliyet |
|---------|------|------|----------|
| 🔴 Kritik | `signOut` anında `fcm_token = null` set et | Gizlilik riski | Hemen |
| 🔴 Kritik | `weather_morning` push tipini weather sekmesine yönlendir | UX bozukluğu | Hemen (1 satır) |
| 🟠 Yüksek | `morning-weather-push` aktif kullanıcı limiti (`limit(1000)`) kaldırılmalı | Bildirim kaçırma | Yakın sprint |
| 🟠 Yüksek | `notification_settings`'e eksik kategoriler eklenmeli (`checkin_spot_owner`, `checkin_favorite`, `rank_up`) | Kullanıcı kontrolü | Yakın sprint |
| 🟠 Yüksek | `force` bildirimlerine kendi kategorisinde sınır getir | Spam riski | Yakın sprint |
| 🟡 Orta | `rank_up` bildirimi profil sayfasına götürmeli (sıralama yerine) | UX iyileştirme | Sonraki sprint |
| 🟡 Orta | Terminated push / `appNavigatorKey.currentContext == null` race condition'ı için bekleme mekanizması | Nadir bug | Sonraki sprint |
| 🟡 Orta | Rütbe yükselmesi push metnine kazanılan ayrıcalığı ekle | Hedef kitle motivasyonu | Metin değişikliği |
| 🟢 Düşük | Bildirim listesi "Geçmiş" sekmesi | UX tamamlama | Gelecek faz |
| 🟢 Düşük | 2000+ kullanıcı için FCM Multicast API entegrasyonu | Ölçek hazırlığı | Gelecek faz |

---

*Bu rapor kaynak kodu analizi ve mobil push bildirim best practice'leri baz alınarak hazırlanmıştır. Herhangi bir kod değişikliği içermez.*
