# Medya Yönetimi, Depolama Maliyetleri ve Topluluk Moderasyonu Analizi

> **Analiz Kapsamı:** Flutter istemci tarafı sıkıştırma, Supabase Storage güvenliği ve oylama/moderasyon mekanizmaları.  
> **Tarih:** Mayıs 2026 — Hiçbir kaynak dosyası değiştirilmemiştir; bu belge salt analiz amaçlıdır.

---

## 1. İstemci Tarafı Sıkıştırma ve Yük Optimizasyonu

### 1.1 Sıkıştırma Mimarisi

Projede **iki katlı sıkıştırma stratejisi** uygulanmaktadır. Tüm medya yüklemeleri (balık fotoğrafı + profil avatarı) `lib/core/utils/avatar_image_prepare.dart` içindeki `prepareAvatarUploadBytes()` fonksiyonundan geçer. 15 MB'lık bir 4K fotoğraf **doğrudan Storage'a pompalanmaz.**

```
Kullanıcı görsel seçer
    └→ Katman 1: flutter_image_compress (native — Android/iOS)
         ├─ maxEdge: 1024px (her iki boyuttan küçük olan)
         ├─ quality: 88'den başlar, 10'ar azalır (88 → 78 → 68 → ... → 38)
         └─ 2MB altına düştüğünde dur
    
    ↓ flutter_image_compress başarısız olursa (web veya hata)
    
    └→ Katman 2: image paketi (pure Dart — web uyumlu)
         ├─ Çözünürlük basamakları: 1024 → 768 → 512 → 384 → 320px
         ├─ Her boyut için kalite: 86 → 78 → 70 → 62 → 54 → 46 → 38 → 32
         └─ Son çare: 256px @ kalite 28
    
    └→ 2MB sınırı yine de aşılıyorsa: Exception fırlatılır
         "Fotoğraf sıkıştırıldıktan sonra hâlâ çok büyük. Başka bir fotoğraf seçin."
```

**Sonuç:** Teorik olarak 15 MB'lık 4K bir görsel 256px + kalite 28 son çare ile ~50–150 KB'a düşürülür. Pratikte büyük çoğunluk 1024px @ kalite 78 ile zaten 2MB altına girer.

### 1.2 `ImagePicker` Ön Sıkıştırması

Balık günlüğü (`add_log_screen.dart`) galeride seçim sırasında ek bir ön kırpma yapar:

```dart
picker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 85,   // ← Galeriden okuma sırasında %85 kalite
  maxWidth: 1600,     // ← Maksimum 1600px genişlik
)
```

Bu, `prepareAvatarUploadBytes()` çağrılmadan önce dosyayı zaten küçültür. Sonuç olarak balık fotoğrafı yükleme süreci **çift aşamalı sıkıştırma** uygular: önce `ImagePicker` (1600px + %85), ardından `prepareAvatarUploadBytes` (1024px hedef + 2MB sınırı).

### 1.3 UI Geri Bildirimi

**Yükleme sırasında ekranın donmadığını anlatan geri bildirim mevcuttur:**

- **Kaydet butonu:** `_isLoading = true` olunca buton devre dışı kalır, ikon `CircularProgressIndicator` ile değişir, etiket "Kaydediliyor..." olur.
- **Fotoğraf yükleme hatası:** Başarısız olursa kayıt fotoğrafsız devam eder ve kullanıcıya turuncu `SnackBar` gösterilir: _"Fotoğraf yüklenemedi — kayıt fotoğrafsız kaydedilecek."_
- **Bekleme:** `setState(() => _isLoading = true)` → `finally { setState(() => _isLoading = false) }` kalıbı, uzun süreli işlemlerde UI'ın donmamasını sağlar.

**Eksik:** Sıkıştırma aşaması (birkaç saniye sürebilir, özellikle pure Dart katmanı) için **ayrı bir "Fotoğraf hazırlanıyor..." mesajı yok.** Kullanıcı sıkıştırma süresince butonun devre dışı olduğunu görür ama işlemin ne aşamada olduğunu bilemez.

### 1.4 Özet Değerlendirme

| Kriter | Durum | Notlar |
|--------|-------|--------|
| İstemci sıkıştırması | ✅ Aktif | flutter_image_compress + image paketi |
| 2MB sınır kontrolü | ✅ Aktif | Exception fırlatılır, kullanıcı bilgilendirilir |
| Çözünürlük düşürme | ✅ Aktif | Maks. 1024px edge (pick: 1600px) |
| Yükleme göstergesi | ✅ Var | Buton + CircularProgressIndicator |
| Sıkıştırma ilerleme göstergesi | ❌ Yok | "Fotoğraf hazırlanıyor..." aşaması belirsiz |
| Web uyumluluğu | ✅ Var | Dart katmanı web'de devreye girer |

---

## 2. Supabase Storage Güvenliği ve Kotalar

### 2.1 Bucket Yapılandırması Karşılaştırması

| Özellik | `users-avatars` | `fish-photos` |
|---------|----------------|---------------|
| Erişim | Public | Public |
| Dosya boyutu limiti | **2 MB** (2.097.152 byte) | **2 MB** (2.097.152 byte) |
| MIME kısıtlaması | ✅ `image/jpeg, image/jpg, image/png, image/webp` | ❌ **`NULL` — Hiçbir kısıtlama yok** |
| Path bazlı izolasyon | `avatars/{uid}/...` | `fish_logs/{uid}/...` |

### 2.2 Kritik Güvenlik Açığı: `fish-photos` MIME Kısıtlaması Yok

`20260415_storage_fish_photos_bucket.sql` migration dosyasında:

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fish-photos', 'fish-photos', true, 2097152, NULL)
--                                                    ^^^^
--                                    MIME kısıtlaması yok — kritik açık!
```

**Saldırı Senaryosu:**
Kimliği doğrulanmış (authenticated) bir kullanıcı Postman veya curl ile şu isteği atabilir:

```bash
curl -X POST https://<proje>.supabase.co/storage/v1/object/fish-photos/fish_logs/<uid>/malware.sh \
  -H "Authorization: Bearer <geçerli_jwt>" \
  -H "Content-Type: application/x-sh" \
  --data-binary @/path/to/malware.sh
```

- **Sonuç:** `.sh`, `.exe`, `.php`, `.html` dosyaları yüklenebilir.
- Bucket `public` olduğundan yüklenen dosya `getPublicUrl()` ile herkese açık erişilebilir olur.
- Phishing, zararlı içerik dağıtımı veya CDN cache poisoning riski doğar.

**2 MB boyut limiti bu saldırıyı önlemez** — 2 MB'lık bir shell script veya HTML sayfası rahatça yüklenebilir.

**Düzeltme:**
```sql
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
WHERE id = 'fish-photos';
```

### 2.3 İstemci MIME Zorlama Tutarsızlığı

`_uploadPhoto()` fonksiyonu içeriği JPEG olarak yüklese de:

```dart
fileOptions: const FileOptions(
  contentType: 'image/jpeg',  // ← İstemci iddia ediyor
  upsert: true,
),
```

Bu `contentType` değeri istemci tarafından belirleniyor. Kötü niyetli bir istemci `contentType: 'application/x-sh'` diyerek zararlı dosya yükleyebilir. **Sunucu tarafında MIME doğrulaması olmadan bu iddia anlamsız.** `allowed_mime_types = NULL` iken bucket her `contentType` değerini kabul eder.

### 2.4 Öksüz Dosyalar (Orphaned Files) Analizi

**Balık Günlüğü (`fish_logs`) Silme Akışı:**

```
Kullanıcı kaydı siler
    └→ FishLogRepository.deleteLog(id)
         └→ Supabase: fish_logs tablosundan DELETE
              ← photo_url Supabase Storage'da kalır!
```

`fish_log_repository.dart` incelendi: `deleteLog()` fonksiyonu yalnızca DB satırını siler; ilişkili `photo_url`'e ait Storage nesnesini silmez. **Çöp dosya birikimi kaçınılmazdır.**

**Check-in Silme Akışı:**

Check-in'lerde fotoğraf yükleme akışı `check-in` ekranında mevcut değil (sadece topluluk oylaması var). `photo_url` alanı check-in tablosunda bulunuyor ancak fotoğraf yükleme akışı şu an aktif değil. Bu nedenle check-in için öksüz dosya sorunu şu an tetiklenmiyor.

**Kullanıcı Hesabı Silinmesi:**

`users-avatars` ve `fish-photos` bucket'larında **kullanıcı silinince Storage dosyaları otomatik silinmiyor.** Supabase Storage cascade silme davranışı bucket politikalarına bağlı; şu an böyle bir tetikleyici yok.

**Öksüz Dosya Risk Özeti:**

| Senaryo | Durum | Risk |
|---------|-------|------|
| Balık kaydı silinince fotoğraf | ❌ Silinmiyor | Depolama maliyeti birikimi |
| Kullanıcı hesabı silinince dosyalar | ❌ Silinmiyor | Veri kalıcılığı + maliyet |
| Check-in iptalinde fotoğraf | ✅ Sorun yok (fotoğraf yükleme aktif değil) | — |
| Avatar değiştirilince eski avatar | ✅ `upsert: true` ile üzerine yazılıyor | — |

**Düzeltme Önerisi:**

```dart
// FishLogRepository.deleteLog() içine eklenecek:
Future<void> deleteLog(String logId) async {
  // 1. Önce fotoğraf URL'ini al
  final row = await _db.from('fish_logs')
    .select('photo_url').eq('id', logId).maybeSingle();
  final photoUrl = row?['photo_url'] as String?;

  // 2. DB kaydını sil
  await _db.from('fish_logs').delete().eq('id', logId);

  // 3. Storage dosyasını sil
  if (photoUrl != null) {
    final path = _extractPathFromUrl(photoUrl); // fish_logs/{uid}/...
    await SupabaseService.storage.from('fish-photos').remove([path]);
  }
}
```

---

## 3. Moderasyon ve Şikayet (Report) Mekanizması

### 3.1 Topluluk Denetimi Mimarisi

Projede **check-in odaklı topluluk oylama sistemi** mevcuttur. "Şikayet" yerine "oy" terminolojisi kullanılmıştır: kullanıcılar check-in'in gerçek mi yanlış mı olduğunu oylar.

```
Kullanıcı "Yanlış Bilgi" oyu verir
    └→ checkin_votes tablosuna INSERT
         └→ trg_checkin_votes_aggregate trigger tetiklenir (AFTER INSERT/UPDATE/DELETE)
              └→ apply_checkin_vote_aggregates() fonksiyonu çalışır
                   ├─ checkin_id için true_votes ve false_votes yeniden sayılır
                   ├─ Eşik kontrolü: total >= 3 VE false_votes/total >= 0.70
                   └─ Eşik aşıldıysa: checkins.is_hidden = true (anında)
```

### 3.2 Otomatik Gizleme — Eşik Analizi

**`apply_checkin_vote_aggregates()` trigger fonksiyonu:**

```sql
is_hidden = CASE
  WHEN total >= 3            -- en az 3 farklı kullanıcı oy vermiş
    AND total > 0
    AND (fcount::numeric / total::numeric) >= 0.70  -- %70 veya daha fazlası "yanlış"
  THEN true
  ELSE is_hidden             -- önceki değer korunur (bir kez gizlendi mi kalır)
END
```

| Koşul | Değer | Açıklama |
|-------|-------|---------|
| Minimum oy sayısı | 3 | Az nüfuslu meralarda eşik zor aşılır |
| Yanlış oy oranı eşiği | %70 | 3 oy → en az 3 yanlış; 10 oy → en az 7 yanlış |
| Gizleme mekanizması | DB trigger (SECURITY DEFINER) | İstemci atlatamaz |
| Geri alınma | Manuel admin müdahalesi gerekir | Trigger gizlemeyi geri almaz |
| Admin müdahalesi | ❌ Otomatik bildirim yok | Dashboard'dan manuel kontrol |

**Güçlü Yönler:**
- Trigger `SECURITY DEFINER` ile çalışır — hiçbir istemci `is_hidden` alanını doğrudan güncelleyemez.
- `SELECT` politikası `is_hidden = false` olan kayıtları filtreler — gizlenen içerikler harita ve listelerden anında kaybolur.
- Oylar `checkin_id UNIQUE per voter_id` kısıtıyla korunur — bir kullanıcı aynı check-in'e birden fazla oy veremez.

### 3.3 Troll Koruması Analizi

**"Sahte hesap açıp rakibin meralarını şikayet etme" saldırısı:**

| Koruma Katmanı | Mevcut Durum | Değerlendirme |
|----------------|-------------|---------------|
| Hesap başına tek oy | ✅ `UNIQUE (checkin_id, voter_id)` kısıtı | Tek hesapla birden fazla oy atılamaz |
| E-posta onayı zorunluluğu | ⚠️ Supabase Auth varsayımı | Onaysız hesapla kayıt olunabiliyorsa açık var |
| Minimum oy eşiği (3) | ✅ Mevcut | Tek troll 3 check-in'i gizleyemez ama 3 sahte hesap açabilir |
| Oy veren rütbe/puan eşiği | ❌ Yok | Acemi (0 puanlı) kullanıcı da oy verebilir |
| Oy veren hesap yaşı kontrolü | ❌ Yok | Yeni açılmış hesap hemen oy kullanabilir |
| Cezalandırma skoru | ⚠️ Kısmi | Yanlış oy verip onaylanan → -20 puan, ama gizlenen içerik için farklı kural yok |
| Rate limiting (oy hızı) | ❌ Yok | Saniyede çok sayıda oy atılabilir |
| Admin dashboard/rapor görünümü | ❌ Yok | Moderatör arayüzü mevcut değil |

**Saldırı Senaryosu — Organize Troll:**

```
1. Saldırgan 3 sahte hesap açar
2. Her hesapla hedefin check-in'ine "Yanlış" oyu atar
3. Trigger: total=3, false_votes=3, oran=1.0 (%100 > %70) → is_hidden = true
4. Hedefin geçerli check-in'i anında haritadan kaybolur
```

Bu senaryo mevcut sistemde **engellenemiyor.** Minimum oy eşiği (3) birden fazla hesaba karşı etkisiz.

**Mevcut kısmi koruma:**
- `checkin_votes.voter_id = auth.uid()` RLS politikası: Her hesap kendi kimliğiyle oy atar, başkası adına oy atamazsın.
- `UNIQUE (checkin_id, voter_id)`: Aynı hesapla çift oy imkânsız.

### 3.4 Fotoğraf İçerik Moderasyonu

**Uygunsuz fotoğraf (check-in veya balık günlüğündeki):**

- **Mevcut mekanizma:** ❌ **Yok.** Fotoğraflar için ayrı şikayet mekanizması tanımlanmamış.
- Oylama sistemi yalnızca **check-in'in gerçek mi yanlış mı** olduğunu değerlendirir; fotoğraf içeriğini değil.
- Kullanıcı yüklediği fotoğrafa hiç oy oy gelmiyor; `fish_logs` tablosunda `is_hidden` alanı yok.
- Google Cloud Vision veya benzer AI moderasyon entegrasyonu mevcut değil.

### 3.5 Özet: Moderasyon Sisteminin Durumu

| Özellik | Durum | Açıklama |
|---------|-------|---------|
| Check-in otomatik gizleme | ✅ Aktif | 3 oy + %70 yanlış eşiği |
| DB trigger güvenliği | ✅ SECURITY DEFINER | İstemci atlatamaz |
| Tekrar oy yasağı | ✅ UNIQUE kısıt | Hesap başına tek oy |
| Sahte hesap troll koruması | ❌ Yok | 3 hesap eşiği aşar |
| Fotoğraf moderasyonu | ❌ Yok | fish_logs'ta is_hidden yok |
| Admin moderatör arayüzü | ❌ Yok | Dashboard manuel |
| Gizlenen içerik geri alımı | ❌ Manuel | Trigger geri alma yazmıyor |
| Rate limiting | ❌ Yok | Hızlı oy saldırısı mümkün |
| Hesap yaşı/rütbe filtresi | ❌ Yok | Yeni hesaplar oy kullanabilir |

---

## 4. Öneri Yol Haritası (Öncelik Sırası)

### 🔴 Hemen (Güvenlik Kritik)

1. **`fish-photos` MIME kısıtlaması ekle:**
   ```sql
   UPDATE storage.buckets
   SET allowed_mime_types = ARRAY['image/jpeg','image/jpg','image/png','image/webp']::text[]
   WHERE id = 'fish-photos';
   ```

2. **Balık kaydı silinince Storage dosyası sil:**
   `FishLogRepository.deleteLog()` içine Storage `remove()` çağrısı ekle.

### 🟠 Kısa Vadeli (Anti-Abuse)

3. **Oy için minimum rütbe veya hesap yaşı şartı:** `checkin_votes INSERT` politikasına `users.total_score >= 50` veya hesap yaşı >= 7 gün koşulu ekle.

4. **İp bazlı rate limiting:** Edge Function üzerinden oylama yapıldıysa, 1 IP'den dakikada max 5 oy kısıtı ekle.

5. **Sıkıştırma ilerleme göstergesi:** `prepareAvatarUploadBytes` çağrılırken "📸 Fotoğraf hazırlanıyor..." `SnackBar` veya LinearProgressIndicator göster.

### 🟡 Orta Vade (Moderasyon Olgunluğu)

6. **`fish_logs.is_hidden` alanı ekle:** Fotoğraf ve günlük raporlama için şikayet tablosu oluştur.

7. **Hesap silinince dosya temizleme:** `auth.users` DELETE trigger'ına Storage cleanup ekle.

8. **Admin moderatör görünümü:** Supabase Dashboard'da özel `admin` rolü için `is_hidden` kayıtlarını listeleyen bir RPC fonksiyonu yaz.

---

*Bu analiz, Mayıs 2026 itibarıyla projenin gerçek kaynak kodundan (`lib/`, `supabase/migrations/`) otomatik analiz ile üretilmiştir. Hiçbir kod değiştirilmemiştir.*
