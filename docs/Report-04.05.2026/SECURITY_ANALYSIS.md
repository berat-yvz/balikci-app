# Veritabanı Güvenliği, RLS ve API Zafiyet Analizi — Kapsamlı Güvenlik Raporu

> **Tarih:** 04 Mayıs 2026  
> **Analiz Edilen Dosyalar:** Tüm `supabase/migrations/*.sql`, tüm `supabase/functions/*/index.ts`, `supabase/cron_*.sql`, `lib/core/services/supabase_service.dart`, `lib/core/constants/app_constants.dart`, `lib/data/repositories/`, `ARCHITECTURE.md`, `MVP_PLAN.md`, `.env`  
> **Kapsam:** Kod değişikliği yok — salt sızma testi ve güvenlik analizi perspektifi  
> **Risk Seviyeleri:** 🔴 Kritik | 🟠 Yüksek | 🟡 Orta | 🟢 Düşük

---

## 1. RLS (Row Level Security) ve Mera Gizliliği Sızıntıları

### 1.1 Anon Kullanıcı Sızma Senaryosu

**Test Senaryosu:** Kullanıcı hesabı olmayan biri, `anon_key` ile doğrudan Supabase REST API'sine şu isteği atar:

```http
GET https://bcsihxgekoqwbovbmlog.supabase.co/rest/v1/fishing_spots?select=*
Authorization: Bearer eyJ... (anon key)
```

**Sonuç Analizi (RLS politikalarına göre):**

| Sorgu | Veri Sızar mı? | Neden |
|-------|----------------|-------|
| `privacy_level = 'public'` | ✅ Görünür | "Public spots visible to all" politikası `USING (true)` değil, `USING (privacy_level = 'public')` — doğru |
| `privacy_level = 'friends'` | ✅ Filtrelenir | anon kullanıcı `auth.uid()` null; `follows` join'i hiçbir şey döndürür |
| `privacy_level = 'private'` | ✅ Filtrelenir | `user_id = auth.uid()` — null = null false |
| `privacy_level = 'vip'` | ✅ Filtrelenir | `auth.uid()` null → `users` sorgusunda satır yok → politika false |

**Sonuç:** `fishing_spots` tablosu anon sorgularına karşı **doğru korunuyor.** Public meraların koordinatları kasıtlı olarak herkese açık; private/friends/vip meraların koordinatları sızmıyor.

---

### 1.2 Kimlik Doğrulamalı Kullanıcı — Sızma Senaryosu

**Test Senaryosu:** Uygulamaya kayıtlı bir "Acemi" rütbeli kullanıcı (500 puanın altında), kendi JWT token'ı ile VIP meralara erişmeye çalışıyor:

```http
GET https://.../rest/v1/fishing_spots?privacy_level=eq.vip&select=*
Authorization: Bearer eyJ...(acemi kullanıcı JWT)
```

**VIP RLS Politikası:**
```sql
CREATE POLICY "VIP spots for usta and above"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'vip'
    AND (SELECT rank FROM users WHERE id = auth.uid()) IN ('usta', 'deniz_reisi')
  );
```

**Sonuç:** `rank` değeri DB'de `auth.uid()` ile sorgulanıyor. İstemci `rank` değerini JWT içinde taşımıyor — DB'deki gerçek değer kullanılıyor. Bu **güvenli ve doğru** tasarım. ✅

**Kritik Not:** JWT claims manipülasyonu bu sistemde işe yaramaz, çünkü RLS politikası JWT'den değil, `public.users.rank` sütunundan okuyor.

---

### 1.3 🟠 YÜKSEK RİSK — "Friends" Politikasında Tek Yönlü Takip Açığı

**Politika:**
```sql
CREATE POLICY "Friends spots visible to followers"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'friends'
    AND user_id IN (SELECT following_id FROM follows WHERE follower_id = auth.uid())
  );
```

**Sızma Senaryosu:** Kullanıcı A, B'nin "friends" merasını görmek istiyor. A, B'yi **tek yönlü takip** ediyor (B, A'yı takip etmek zorunda değil). A, B'nin tüm `friends` meraları koordinatlarını görüyor.

Bu, `follows` tablosunun tek yönlü takip ilişkisi kurduğu bir sistemde "friends" kavramının karşılıklı onay gerektirmediği anlamına geliyor. Mera sahibi B, bilinçli olarak A'yı "arkadaş" olarak onaylamamış bile olabilir; A sadece B'yi "takip" ederek friends meralarına erişebilir.

**Etki:** Herhangi bir kullanıcı, "friends" gizlilik seviyesindeki meralara sahip birini **tek taraflı takip ederek** koordinatlarına erişebilir.

**Öneri:** `accept_friend_request` RPC zaten karşılıklı `follows` ilişkisi kuruyor (`accept_friend_request` → iki yönlü follows INSERT). Bu yol kullanıldığında sorun azalır. Ancak UI'da "arkadaş ol" ve "takip et" kavramları ayrıştırılmalı; "friends" meraları yalnızca karşılıklı follow (yani arkadaşlık) ilişkisinde gösterilmeli.

---

### 1.4 🟡 ORTA RİSK — `checkins` UPDATE Politikası Geniş

```sql
-- 20240601_checkin_hide_policy.sql
CREATE POLICY "Owner can deactivate own checkin"
  ON checkins FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

Bu politika, check-in sahibinin kendi check-in'ini **herhangi bir sütunu güncellemesine** izin veriyor. Kullanıcı `is_hidden = false` yaparak gizlenmiş (cezalandırılmış) check-in'ini tekrar görünür yapabilir; `true_votes`, `false_votes` sayaçlarını sıfırlayabilir; `crowd_level`, `fish_density` değerlerini geriye dönük değiştirebilir.

**Öneri:** `WITH CHECK` içine izin verilen sütunları sınırlayan kısıtlar eklenmelidir:
```sql
WITH CHECK (
  user_id = auth.uid()
  AND is_hidden = (SELECT is_hidden FROM checkins WHERE id = NEW.id)
  AND true_votes = (SELECT true_votes FROM checkins WHERE id = NEW.id)
  AND false_votes = (SELECT false_votes FROM checkins WHERE id = NEW.id)
);
```

---

### 1.5 🟡 ORTA RİSK — RLS Olmayan Tablo: `shadow_points`

`shadow_points` tablosu şemada tanımlı ancak herhangi bir migration dosyasında `ENABLE ROW LEVEL SECURITY` veya politika tanımı yok. Eğer tablo DB'de oluşturulmuşsa ve RLS aktif edilmemişse, kimliği doğrulanmış **herhangi bir kullanıcı** diğer kullanıcıların gölge puan kayıtlarını okuyabilir, hatta yazabilir.

**Öneri:** `shadow_points` tablosu oluşturulurken mutlaka:
```sql
ALTER TABLE shadow_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY "shadow_points_owner_read" ON shadow_points FOR SELECT
  USING (receiver_id = auth.uid());
CREATE POLICY "shadow_points_service_only_write" ON shadow_points FOR INSERT
  WITH CHECK (false); -- Yalnızca service_role (Edge Function) yazabilir
```

---

## 2. API Güvenliği, Edge Functions ve Yetkilendirme

### 2.1 🔴 KRİTİK — Hardcoded Placeholder Service Role Key

**Konum:** `supabase/migrations/20240002_exif_storage_trigger.sql` — Satır 25

```sql
'Authorization', 'Bearer BURAYA_SERVICE_ROLE_KEY_YAZ'
```

Bu migration dosyası Git reposunda **açık metin** placeholder bir service role key içeriyor. Bu değer işlevsel değil (gerçek key değil) ama ciddi bir güvenlik pratiği ihlali:

1. Gerçek key buraya girilip commit edilseydi, service role key kalıcı olarak Git geçmişine girmiş olurdu.
2. Bir developer bu migration'ı kopyala-yapıştır ile bir CI/CD pipeline'ına taşıyıp gerçek key ile doldurursa risk somutlaşır.
3. Bu migration'ın storage trigger'ı `exif-verify` Edge Function'ı tetikliyor — bu trigger artık check-in akışında devre dışı bırakılmış (ARCHITECTURE.md bunu teyit ediyor). Yani trigger aktif değil, ancak migration dosyası tehlikeli pratiği içeriyor.

**Öneri:**
- Placeholder metni `'Bearer ' || current_setting('app.service_role_key', true)` veya Vault referansıyla değiştir.
- Gerçek bir key asla migration SQL dosyasına yazılmamalı.

---

### 2.2 ✅ GÜÇLÜ — Flutter İstemcisinde Hardcoded Key Yok

`supabase_service.dart` incelemesinde:
```dart
final url = dotenv.env['SUPABASE_URL'] ?? '';
final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
```
`flutter_dotenv` ile `.env` dosyasından okunuyor. `.env` dosyası `.gitignore`'a eklenmiş. `service_role_key` Flutter kaynak kodunda **hiçbir yerde yok.** ✅

Edge Functions içindeki `service_role_key` kullanımı:
```typescript
Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
```
Tüm Edge Function'larda environment variable'dan okunuyor — hardcoded yok. ✅

**Ancak dikkat:** `.env` dosyasında gerçek `SUPABASE_ANON_KEY` değeri görünüyor:
```
SUPABASE_ANON_KEY=sb_publishable_UrBz2yJnupWn1Hy__EbjwA__3BGOTxf
```
`anon_key`, kamuya açık (publishable) bir değer olduğundan bu kabul edilebilir. Ancak bu dosya repodan dışarı sızarsa proje URL'i de sızmış olur — birinin projeye istek atmasını kolaylaştırır (ama RLS sayesinde yetkisiz veri erişimi kısıtlanmış).

---

### 2.3 🟠 YÜKSEK RİSK — Edge Functions JWT Doğrulaması Eksik

**Sorun:** `weather-cache`, `morning-weather-push`, `season-reminder-push` ve `nearby-checkin-notifier` fonksiyonlarının hiçbirinde gelen HTTP isteğinin JWT token'ını doğrulayan bir kod yok.

Örnek `weather-cache/index.ts`:
```typescript
serve(async (req: Request) => {
  // JWT doğrulama yok!
  if (req.method !== 'POST' && req.method !== 'OPTIONS') { ... }
  const supabase = createClient(url, key) // service_role ile çalışıyor
  // ...
```

**Saldırı Senaryosu (Maliyet/Fatura Saldırısı):** Anonim bir saldırgan, bu endpoint'lere bot ile art arda istek atarsa:

1. `weather-cache` her çağrıda 12 bölge + 39 ilçe = **51 adet Open-Meteo API çağrısı** yapıyor. Saatte bir bot, günde 24 × 51 = 1224 gereksiz Open-Meteo çağrısı üretiyor.
2. `morning-weather-push` her çağrıda tüm aktif kullanıcılara push bildirimi gönderiyor — bot bu endpoint'i saatte bir tetiklerse kullanıcılar spam push alır.
3. Supabase Edge Function çağrı limiti (500K/ay ücretsiz tier) hızla tükenir.

**Teknik neden:** Supabase Edge Functions varsayılan olarak anonim erişime açık. JWT doğrulama için `Authorization` header'ı kontrol eden kod eklemek gerekiyor.

**Öneri:**
```typescript
// Her cron-triggered Edge Function'da başa ekle:
const authHeader = req.headers.get('Authorization')
const expectedToken = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
if (!authHeader || authHeader !== `Bearer ${expectedToken}`) {
  return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
}
```

Alternatif: Supabase Dashboard'dan bu fonksiyonlara "JWT required" ayarı yapılabilir; ardından yalnızca geçerli Supabase JWT'ler (authenticated kullanıcılar veya service_role) çağırabilir.

---

### 2.4 🟡 ORTA RİSK — `score-calculator` İstemci Tarafından Doğrudan Çağrılıyor

`checkin_screen.dart`:
```dart
unawaited(ScoreService.award(uid, ScoreSource.checkinUnverified));
```

`score-calculator` Edge Function, `user_id` ve `source_type` parametresi alarak puan güncelliyor. Bu fonksiyona JWT doğrulama yapıyor mu? Kontrol:

```typescript
serve(async (req: Request) => {
  const { source_type, user_id } = await req.json()
  // Herhangi bir kullanıcının kim adına puan istediğine dair doğrulama yok!
  const delta = POINTS[source_type] ?? 0
  await supabase.from('users').update({ total_score: newScore, rank: newRank }).eq('id', user_id)
})
```

**Saldırı Senaryosu:** Kullanıcı, kendi JWT'si ile `score-calculator`'ı çağırırken `user_id` olarak başkasının UUID'sini gönderiyor. Edge Function o kullanıcının puanını güncelliyor — yani **herhangi bir kullanıcının puanı isteğe bağlı artırılabilir veya azaltılabilir.**

Bu, `service_role_key` gerektirdiğinden Supabase SDK üzerinden çağrılabiliyor ancak fonksiyonun JWT doğrulama mekanizması şu an "herhangi bir authenticated kullanıcıdan gelen istek" seviyesinde. İstemci tarafından gelen `user_id` parametresi doğrulanmıyor.

**Öneri:** `score-calculator` içinde `req`'ten JWT çözümleyip `auth.uid()` ile eşleştir:
```typescript
// JWT'den gerçek user_id'yi çek; request body'den geleni güven
const jwt = req.headers.get('Authorization')?.replace('Bearer ', '')
const { data: { user } } = await supabase.auth.getUser(jwt)
const trustedUserId = user?.id ?? user_id // JWT'deki id'yi kullan
```

---

## 3. Suistimal Koruması (Abuse Prevention) ve Storage

### 3.1 ✅ İYİ — Storage Dosya Boyutu Limiti Mevcut

Her iki Storage bucket için:
```sql
-- users-avatars ve fish-photos
file_size_limit = 2097152  -- 2 MB
```

2MB limiti Supabase Storage seviyesinde enforce ediliyor. Flutter istemci tarafında da:
```dart
static const maxPhotoSizeBytes = 2 * 1024 * 1024; // 2 MB
```

Büyük dosya yükleme girişimi `413 Payload Too Large` ile reddedilir. ✅

---

### 3.2 🟠 YÜKSEK RİSK — `fish-photos` Bucket MIME Tipi Kısıtlaması Yok

```sql
-- fish-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fish-photos', 'fish-photos', true, 2097152, NULL)  -- ← allowed_mime_types NULL!
```

Karşılaştırma: `users-avatars` doğru yapılandırılmış:
```sql
allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
```

`fish-photos` bucket'ına 2MB boyutunu geçmemek kaydıyla **herhangi bir dosya türü** yüklenebilir: `.exe`, `.html` (XSS), `.svg` (XSS payload ile), `.zip`, `.pdf` vb.

**Saldırı Senaryosu:**
1. Saldırgan, balık fotoğrafı yerine SVG içinde `<script>` embedded bir dosya yüklüyor.
2. Bucket `public: true` olduğundan public URL alınabiliyor.
3. Bu URL başka bir kullanıcıya gönderilip açtırılırsa SVG üzerinden XSS saldırısı mümkün.

**Öneri:**
```sql
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
WHERE id = 'fish-photos';
```

---

### 3.3 🟡 ORTA RİSK — Storage Yükleme Sıklığı Rate Limiting Yok

Şu an bir kullanıcı dakikada kaç kez fotoğraf yükleyebilir? Sınır **yok.** Storage politikası yalnızca "kendi klasörüne yükle" kısıtı var:

```sql
WITH CHECK (
  bucket_id = 'fish-photos'
  AND name LIKE ('fish_logs/' || auth.uid()::text || '/%')
);
```

**Saldırı Senaryosu:** Bot, kimliği doğrulanmış bir token ile dakikada yüzlerce 2MB dosya yüklüyor → Supabase Storage kotası (1GB ücretsiz tier) dakikalar içinde dolabilir.

**Öneri:** Supabase, Storage için yerleşik rate limiting sunmuyor; ancak bunu Edge Function proxy ile uygulanabilir. Daha pratik çözüm: mobil istemci tarafında her upload öncesi minimum süre kontrolü (throttle).

---

### 3.4 Mock GPS / Sahte Konum Analizi

**Mevcut koruma:** `checkin_screen.dart` konum doğrulaması:
```dart
if (distMeters > AppConstants.checkinRadiusMeters) { // 500m
  // "Meradan çok uzaksın" uyarısı
  return;
}
```

Bu kontrol **tamamen istemci tarafında** yapılıyor. Sunucu check-in payload'ını alırken konumu doğrulamıyor.

**Saldırı Senaryosu (Mock GPS):**
1. Saldırgan Android cihazında "Fake GPS" uygulaması açıyor.
2. İstediği meranın koordinatını GPS olarak ayarlıyor.
3. Uygulama istemci tarafındaki 500m kontrolünü geçiyor.
4. Check-in başarıyla oluşturuluyor, puan kazanıyor.
5. Aynı kişi 10 farklı sahte GPS ile 10 farklı mera için check-in yapıp puan topluyor.

**Mevcut hafifletici etken:** Check-in `crowd_level` ve `fish_density` raporları topluluk oylaması ile doğrulanıyor. Sahte raporlar gerçek kullanıcılar tarafından "Yanlış" oylanırsa gizleniyor ve -20 puan cezası var. Bu sosyal doğrulama mekanizması kısmen koruyucu.

**Backend seviyesinde önleme önerileri:**

1. **Velocity Check:** Aynı kullanıcının son X dakika içinde aynı merada birden fazla check-in yapmasını sunucu tarafında engelle:
   ```sql
   -- checkins tablosuna unique constraint
   CREATE UNIQUE INDEX idx_checkin_user_spot_daily
   ON checkins (user_id, spot_id, DATE(created_at));
   ```

2. **Coğrafi tutarlılık:** İki ardışık check-in arasındaki mesafe / zaman oranı fiziksel olarak imkânsızsa (örn. 2 dakikada İstanbul'dan İzmir'e) sunucu red edebilir. Bu, Edge Function'a ek mantık gerektiriyor.

3. **Anomali Tespiti:** `score-calculator`'a "son 24 saatte bu kullanıcıdan kaç check-in" sayacı ekleyerek günde N'den fazla check-in puanını durdurabilirsin.

---

## 4. 45+ Yaş Amca Güvenlik/Gizlilik UX Stratejisi

### 4.1 Hedef Kitlenin Gizlilik Kaygısı

"Benim gizli meramı başkası öğrenir mi?" sorusu hedef kitle için **varoluşsal bir kaygı**. Balıkçılar, özel mera bilgisini yıllarca biriktirmiş ve bunu sahiplik duygusuyla koruyor. Teknik güvenlik iyi olsa bile, kullanıcı bunu *hissetmezse* güven oluşmaz.

### 4.2 Mera Oluştururken Gizlilik Seçimi

**Mevcut durum:** Gizlilik seviyesi bir dropdown/radio ile seçiliyor.

**Öneri — Her Seçenek Yanına Güvence Metni Ekle:**

```
🌍 Herkese Açık
   "Konumun haritada görünür. Seni tanımayan herkes görebilir."

👥 Sadece Arkadaşlarım
   "🔒 Sadece senden arkadaşlık isteği kabul ettiğin kişiler görür."

🔒 Yalnızca Ben
   "🛡️ Sadece sen görürsün. Supabase veritabanında kilitli."

👑 VIP — Güvenilir Balıkçılar
   "⚓ Sadece Usta ve Deniz Reisi rütbesindeki balıkçılar görebilir."
```

### 4.3 Haritada Gizli Mera Pin Davranışı

**Öneri:** Kullanıcının kendi gizli merasına tıkladığında pop-up'ta belirgin bir kilit rozeti göster:

```
🔒 Bu mera gizli
"Bu meranın tam konumunu sadece sen görüyorsun.
 Başkasının görmesi için Herkese Açık olarak değiştirmen gerekir."
```

### 4.4 Güvenlik Güvence Önerileri — UI Maddeleri

1. **Profil Ekranı — "Gizlilik Özeti" Kartı:**
   ```
   🛡️ Gizlilik Durumun
   • 3 meran herkese açık
   • 2 meran sadece arkadaşlarına açık
   • 1 mera tamamen gizli
   [Meraları Yönet →]
   ```

2. **İlk Mera Ekleme — Güven Veren Onay Mesajı:**
   > "✅ Mera 'Gizli' olarak kaydedildi. Bu konumu sadece sen görebilirsin — kimseyle paylaşmadığın sürece güvende."

3. **Ayarlar Ekranı — "Verilerimin Güvenliği" Bölümü:**
   Teknik terimler olmadan, sade dille:
   - "Balık meranların şifreli sunucularda saklanır"
   - "Gizli meranı biz de açamayız, başkasına veremeyiz"
   - "İstediğin zaman meranı silebilirsin"

4. **Bilgi Paylaşımı Açıklaması — Onboarding'de:**
   Onboarding'in 3. adımına ekle:
   > "📍 Konum bilgin sadece balık tuttuğun anlarda kullanılır. Uygulama seni sürekli takip etmez."

5. **"Friends" Mera Paylaşımında Kullanıcıya Net Bilgi:**
   ```
   ⚠️ "Arkadaşlarım" seçeneği kimler için?
   Sadece sen arkadaşlık isteği onayladığın kişiler.
   Seni takip eden herkes göremez — sadece onayladıkların.
   ```
   Bu mesaj, "tek yönlü takip = friends erişimi" riskini UI seviyesinde kısmen kapatır.

---

## 5. Özet — Risk Matrisi

| # | Bulgu | Önem | Kategori |
|---|-------|------|----------|
| 1 | `20240002_exif_storage_trigger.sql` içinde hardcoded placeholder key | 🔴 Kritik | API Güvenliği |
| 2 | `score-calculator` user_id parametresi JWT ile doğrulanmıyor | 🔴 Kritik | Yetkilendirme |
| 3 | `fish-photos` bucket'ta MIME tipi kısıtlaması yok | 🟠 Yüksek | Storage |
| 4 | `weather-cache`, `morning-weather-push`, `season-reminder-push` JWT doğrulaması yok | 🟠 Yüksek | API Güvenliği |
| 5 | "Friends" meraları tek yönlü takiple erişilebiliyor | 🟠 Yüksek | RLS / Gizlilik |
| 6 | `shadow_points` tablosunda RLS tanımlı değil | 🟠 Yüksek | RLS |
| 7 | Mock GPS ile check-in puan kasma (sunucu doğrulaması yok) | 🟠 Yüksek | Suistimal |
| 8 | `checkins` UPDATE politikası geniş (sayaç manüpülasyonu) | 🟡 Orta | RLS |
| 9 | Storage yükleme sıklığı sınırsız | 🟡 Orta | Suistimal |
| 10 | Supabase Project URL `.env`'de açık metin (anon key ile birlikte) | 🟢 Düşük | Bilgi Sızıntısı |

---

*Bu rapor kaynak kodu analizi ve penetration test metodolojisi baz alınarak hazırlanmıştır. Herhangi bir kod değişikliği içermez.*
