# Oyunlaştırma, Puan Ekonomisi ve Mera Erişim Mekanizmaları — Kapsamlı Analiz Raporu

> **Tarih:** 04 Mayıs 2026  
> **Analiz Edilen Dosyalar:** `ARCHITECTURE.md`, `MVP_PLAN.md`, `score_service.dart`, `score_utils.dart`, `spot_model.dart`, `checkin_model.dart`, `user_model.dart`, `checkin_screen.dart`, `spot_repository.dart`, `score-calculator/index.ts`, tüm ilgili Supabase migration SQL'leri  
> **Kapsam:** Kod değişikliği yok — salt analiz ve öneri

---

## 1. Puan, Rütbe ve Gölge Puan Sistemi Analizi

### 1.1 Mekanizma Okuması — Mevcut Puan Tablosu

Kodda (`score_utils.dart` + `score-calculator/index.ts`) tanımlı puan kaynakları:

| Eylem | Puan | Kod Sabiti | Durum |
|-------|------|------------|-------|
| Genel mera paylaşımı (`public`) | **+50** | `spot_public` | ✅ Aktif |
| Doğrulanmış check-in (EXIF onaylı) | **+30** | `checkin_verified` | ⚠️ Check-in'de EXIF kaldırıldı; bu kaynak tetiklenmiyor |
| Doğrulanmamış check-in | **+15** | `checkin_unverified` | ✅ Aktif (tek check-in puanı) |
| Doğru rapor oyu almak | **+10** | `correct_vote` | ✅ Aktif |
| Günlük balık kaydı (`public`) | **+10** | `fish_log_public` | ✅ Aktif |
| Balığı salma + EXIF doğrulama | **+40** | `release_exif` | ✅ Aktif (balık günlüğü için) |
| Gölge puan (pasif) | **+20** | `shadow_point` | ❌ Edge Function **yok** |
| Yanlış rapor cezası | **−20** | `wrong_report` | ✅ Aktif |

**Kritik Bulgu:** `checkin_verified` (+30) kaynağı kod sözleşmesinde tanımlı ama check-in akışında EXIF kaldırıldığı için artık çağrılmıyor. Tüm check-in'ler `checkin_unverified` (+15) ile ödüllendiriliyor. Böylece puan tablosunda "doğrulanmış" ile "doğrulanmamış" arasındaki fark anlamsız hale gelmiş; kullanıcıya sunulan değer önerisi eksik.

---

### 1.2 Rütbe Eşiklerinin Motivasyon Analizi

| Rütbe | Eşik | Kazanım Hızı Hesabı | Yorum |
|-------|------|---------------------|-------|
| 🪝 Acemi | 0 — 499 | 0 puan | Başlangıç |
| 🎣 Olta Kurdu | **500** | ~10 check-in + 3 mera paylaşımı | Ulaşılabilir; ilk hafta mümkün ✅ |
| ⚓ Usta | **2000** | ~80 check-in veya 34 mera | Makul; 2-4 ay aktif kullanım ✅ |
| 🌊 Deniz Reisi | **5000** | ~200 check-in veya 85 mera | Uzun vadeli hedef ✅ |

**Sonuç:** Rütbe eşikleri makul bir büyüme eğrisi çiziyor. Hedef kitle (45+ yaş, hafta sonu balıkçısı) için Olta Kurdu ilk ay içinde ulaşılabilir; bu ilk motivasyon zirvesini iyi zamanlar. Usta rütbesi 2-4 ay arası düzenli kullanımla kırılabilir; Deniz Reisi ise uzun vadeli bir "gurur rozeti" işlevi görüyor.

**Eksiklik:** Rütbeler arasında görünür bir **ara hedef** (mini milestone, rozet veya özel unvan) bulunmuyor. Özellikle Olta Kurdu → Usta arası 1500 puanlık uzun boşluk kullanıcıyı bıktırabilir. Ara kilometre taşları (örn. 1000 puanda "Tecrübeli Balıkçı" rozeti) motivasyonu canlı tutar.

---

### 1.3 Gölge Puan Güvenlik Analizi

**Mekanizma nasıl kurgulanmış (dokümana göre):**  
Bir kullanıcı mera paylaşırsa, o meraya başka biri gidip av yapınca mera sahibi +20 "gölge puan" kazanıyor. Bu, mera paylaşımını teşvik eden pasif gelir mekanizması.

**Mevcut durum (kod taramasına göre):**

> ⛔ `shadow-point-calculator` Edge Function **bu repoda yok.** `shadow_points` tablosu şema olarak tanımlanmış; `score_utils.dart`'ta sabit değeri var (+20); ancak tetikleyici, hesaplama mantığı ve bildirim **tamamen eksik.** Sistem şu an işlevsiz.

**Eğer sistem implement edilirse — Olası Loophole'lar:**

1. **Sahte Hesap Çemberi (Sybil Attack):** Kullanıcı A mera paylaşır, kendi kontrolündeki B ve C hesapları o meraya check-in yapar. A, her check-in başına +20 gölge puan toplar.

   *Mevcut savunma:* Yok — `shadow_points` tablosunda `giver_id` / `receiver_id` var ama duplikasyon önleyici UNIQUE kısıtı yok.

2. **Check-in Bombası:** Bir hesap aynı meraya art arda check-in yaparak mera sahibine sürekli gölge puan kazandırabilir. Checkin tablosunda aynı kullanıcının aynı mera için 6 saat içinde birden fazla check-in yapmasını engelleyen kural **yok.**

3. **Gölge Puan - Gerçek Av Bağlantısı Eksik:** Mevcut tasarıma göre gölge puan "Takipçi o meraya gidip av yaptı" koşuluna bağlı; ancak `fish_logs` ile `checkins` arasında ilişki kuran bir mekanizma kodda tanımlı değil. Pratikte gölge puan check-in mi, fish_log mu, ikisi birden mi gerektirir — belirsiz.

**Önerilen Güvenlik Katmanları:**

- **Loophole 1 (Sybil) için:** `shadow_points` tablosuna `UNIQUE(source_id, receiver_id)` kısıtı ekle. Aynı check-in/fish_log için aynı mera sahibine yalnızca bir gölge puan verilsin.
- **Loophole 2 (Flood) için:** `checkins` tablosuna PostgreSQL düzeyinde rate-limit kısıtı ekle: `UNIQUE(user_id, spot_id, DATE(created_at))` — günde bir kez check-in kuralı.
- **Loophole 3 (Bağlantı) için:** Gölge puan tetikleyicisini yalnızca **fish_log INSERT** üzerinden çalıştır (check-in değil), ve `fish_log.spot_id` ile `fishing_spots.user_id` join yaparak mera sahibini bul.
- **Ek koruma:** `giver_id` ≠ `receiver_id` kontrolü; kullanıcının kendi merasına kendi balık logu atarak kendi kendine gölge puan toplamasını engelle.

---

### 1.4 Mera Muhtarlığı Analizi

**Tasarım amacı:** Bir merada en çok/en doğru raporu giren kullanıcı "Mera Muhtarı" unvanı kazanır. `fishing_spots.muhtar_id` alanı bu kişiyi işaret eder.

**Mevcut kod durumu:**

> ⛔ **Muhtarlık ataması için hiçbir otomatik mekanizma yok.** `muhtar_id` alanı şemada tanımlı; `SpotModel`'de `muhtarId` var; UI'da rozet gösterimi "kısmen kullanılabilir" olarak işaretlenmiş. Ancak:
> - Haftalık cron job veya otomatik atama mantığı yok.
> - "En çok/doğru rapor" metriğini hesaplayan Edge Function yok.
> - `muhtar_id`'nin otomatik güncellendiği DB trigger yok.
> - Deniz Reisi rütbesi "Muhtar adaylığı" ayrıcalığı olarak belirtilmiş ama doğrulama mekanizması kodlanmamış.

**Muhtarlık için tamamlanması gereken bileşenler:**

1. **Metrik seçimi:** "En çok check-in" mi, "en çok olumlu oy alan rapor" mu, "en uzun süredir aktif" mi? Tasarım belgelerinde tanımsız. Öneri: `true_votes / (true_votes + false_votes)` oranı ≥ 0.80 AND en az 5 check-in olan, en yüksek toplam `true_votes` sahibi kullanıcı.
2. **Periyot:** Haftalık mı, aylık mı, kümülatif mi? Kümülatif sistem bir kez kazanılıp sonsuza kadar korunabildiğinden rekabeti öldürür. **Aylık rotasyon** önerilir.
3. **Rütbe şartı:** Deniz Reisi şartı kodda uygulanmıyor; sadece dokümanda var. RLS veya Edge Function içinde kontrol gerekli.
4. **Cron Job:** `supabase/functions/` altında `muhtar-rotator` Edge Function + aylık cron SQL eklenmeli.

---

## 2. Mera Gizliliği ve Konum Erişim Mantığı

### 2.1 Erişim Kapıları — Mevcut RLS Analizi

Sistem 4 katmanlı gizlilik uygular. Aşağıda her katmanda **gerçekte ne yapıldığı** kod incelenerek belgelendi:

| Gizlilik Seviyesi | RLS Politikası | Pin Rengi | Koordinat Erişimi |
|-------------------|----------------|-----------|-------------------|
| `public` | Herkes görebilir | 🟢 Yeşil | Tam koordinat herkese açık |
| `friends` | Yalnızca `follows` tablosunda `following_id` olan kullanıcılar | 🔵 Mavi | Tam koordinat takipçilere açık |
| `private` | Yalnızca `user_id = auth.uid()` | ⚫ Gri | Yalnızca sahip |
| `vip` | `rank IN ('usta', 'deniz_reisi')` | 🟡 Altın | 2000+ puan sahipleri |

**Önemli Güvenlik Bulgusu — VIP Politikası:**  
Mevcut RLS politikası:
```sql
CREATE POLICY "VIP spots for usta and above"
  ON fishing_spots FOR SELECT
  USING (
    privacy_level = 'vip'
    AND (SELECT rank FROM users WHERE id = auth.uid()) IN ('usta', 'deniz_reisi')
  );
```
Bu sorgu her SELECT çağrısında `users` tablosunu okuyarak kullanıcının rütbesini denetliyor. RLS içindeki alt sorgu performans riski taşır (N+1 benzeri etki). Rütbe bilgisi `auth.jwt()` claims'ine taşınırsa veya `users` üzerinde index var ise (id PRIMARY KEY zaten indexed) bu risk düşük; ancak 10.000+ kullanıcıda monitor edilmeli.

**"Friends" Politikasının Tek Yönlü Takip Sorunu:**  
`follows` tablosu tek yönlü takip ilişkisini tutuyor (A → B). "Arkadaşlar" seviyesi, meranın sahibini takip eden herkesi kapsıyor. Biri seni takip etmeden sen onu takip edebilirsin — bu, mera sahibinin kontrolü dışında gizli merasını paylaşmış sayılmasına yol açabilir. 

*Öneri:* `friends_accept_friend_request` (zaten `accept_friend_request` RPC ile karşılıklı follows ekleniyor) akışı kullanılıyorsa sorun azalır. Ancak sistemin "takip" ile "arkadaşlık" ayrımını netleştirmesi gerekiyor — mevcut UI'da bu ayrım kullanıcıya açık görünmüyor.

**Koordinat Hassasiyeti (Önemli Eksiklik):**  
Sistem şu an koordinatları **tam hassasiyette** (double precision) ya gösteriyor ya da hiç göstermiyor. Arada bir seviye daha (bulanık/yaklaşık konum) yok. Önerilen gelişim:

- `public` meralar için haritada **tam pin** göster
- `vip` meralar için rütbesi yetmeyen kullanıcıya haritada **~500m yarıçaplı bulanık pin** veya "Bu bölgede bir VIP mera var" mesajı
- `private` meralar için hiçbir ipucu verme

Bu kademeli yaklaşım hem merak uyandırır hem de erişim elde etmek için rütbe kazanmayı teşvik eder.

---

### 2.2 Ekonomi Dengesi — "Ver-Al" Analizi

**Sistemin temel ekonomik dengesi:**

```
Veren (katkıda bulunan):
  ✅ Mera paylaşanlar puan kazanır
  ✅ Check-in yapanlar puan kazanır
  ✅ Balık salarak sürdürülebilirlik puanı kazanır

Alan (tüketen):
  ✅ VIP meralar için 2000+ puan gerekiyor (Usta rütbesi)
  ✅ Friends meraları için takipçi ilişkisi gerekiyor
  ❌ Sistematik "içerik sömürgeni" filtresi YOK
```

**Boşluk:** Bir kullanıcı hiç mera paylaşmadan, yalnızca başkalarının açık merasına check-in yaparak 500+ puan toplayıp Olta Kurdu olabilir ve arkadaş meralarına erişebilir. Bu, mera paylaşımını gerçekten ödüllendiren bir ekonomi değil — check-in yapma ekonomisi.

**Somut Senaryo — Sömürgeci Kullanıcı:**
- 0 mera paylaşımı
- 40 check-in → +600 puan → Olta Kurdu
- Artık takipçi olduğu herkese ait gizli meralar görünür

**Önerilen Filtreleme Kuralları:**

1. **Katkı Oranı Şartı:** Bir gizlilik seviyesine erişim için hem puan hem de minimum mera sayısı şartı getir:
   - `friends` seviyesine erişim: ≥ 500 puan **VE** ≥ 1 `public` mera paylaşımı
   - `vip` seviyesine erişim: ≥ 2000 puan **VE** ≥ 3 `public` mera paylaşımı

2. **"Aktif Katkı" Puanı:** `total_score` yerine son 30 günde kazanılan puanı da ölçen bir aktivite skoru tut. Uzun süre pasif olan kullanıcıların VIP erişimi otomatik askıya alınabilir.

3. **Mera/Tüketim Oranı:** Profil ekranında kullanıcıya kendi katkı/tüketim oranını göster. "Sen 5 mera paylaştın, 20 meranın bilgisine erişttin" gibi şeffaf bir metrik hem dürüstlük hem de paylaşım teşviki sağlar.

---

## 3. 45+ Yaş Amca UX/UI Stratejisi

### 3.1 Hedef Kitlenin Dijital Profili

Balıkçı uygulamasının hedef kitlesinin büyük bölümü:
- Akıllı telefonun temel işlevlerini (WhatsApp, Facebook, telefon) kullanıyor
- Oyunlaştırma, XP, "rank" gibi kavramlara yabancı
- "Neden puan topluyorum? Ne işe yarayacak?" sorusunu soracak
- Büyük, net ikonlar ve Türkçe kelimeler istiyor
- Motivasyonu "saygınlık" ve "yardımcı olmak" üzerine kurulu, not "achievement unlocked"

### 3.2 Dil ve Kelime Önerileri

Teknik kavramların hedef kitleye uyarlanmış karşılıkları:

| Teknik Terim | ❌ Kullanma | ✅ Kullan |
|---|---|---|
| `total_score` | "Puan: 1250" | "**1.250 Balıkçı Puanın var**" |
| `rank: acemi` | "Rütbe: Acemi" | "**Henüz yeni başladın** 🪝" |
| `rank: olta_kurdu` | "Rütbe: Olta Kurdu" | "**Olta Kurdusu oldun!** 🎣 Tebrikler!" |
| `rank: usta` | "Rütbe: Usta" | "**Usta Balıkçı** ⚓ — Gizli meralara artık girebilirsin" |
| `rank: deniz_reisi` | "Rütbe: Deniz Reisi" | "**Deniz Reisi** 🌊 — En seçkin balıkçılardan birisin" |
| `privacy_level: vip` | "VIP Mera" | "**Gizli Mera** — Sadece Usta balıkçılar görür" |
| `shadow_points` | "Gölge Puan" | "**Mahalle Katkı Puanı** — Seninle paylaştığın yer sayesinde!" |
| `muhtar_id` | "Mera Muhtarı" | "**Bu meranın Sorumlusu**" (muhtar zaten anlaşılır) |
| `checkin` | "Check-in" | "**Buraya geldim!**" / "**Balık var bildirimi**" |
| `sustainability_score` | "Sürdürülebilirlik Skoru" | "**Doğayı Koru Puanın**" |

### 3.3 Arayüz Geri Bildirim Önerileri (Madde Madde)

**A — Puan Kazanımı Bildirimi:**
```
❌ Kötü: "checkin_unverified: +15 puan kazandınız"
✅ İyi:  "🎣 +15 Puan! Bildirim gönderildi — Allah bol balık versin!"
```
Büyük, renkli, geçici toast mesajı. Animasyonlu +puan gösterimi (sayı yukarı tırmanan efekt). İkon büyük olsun (en az 48px).

**B — Rütbe Yükselmesi:**
- Tam ekran kutlama ekranı açılsın (küçük popup yetmez)
- "🎉 TEBRİKLER! Artık OLTA KURDUSU oldun!" yazısı büyük punto
- "Bundan sonra arkadaşlarının gizli merasına bakabilirsin" — kazandığı somut ayrıcalığı hemen söyle
- Paylaş butonu: "Bunu WhatsApp'ta paylaş" (Facebook değil, hedef kitle WhatsApp kullanıcısı)

**C — Puan Gösterimi (Profil Ekranı):**
- Sayılar çok soyut; **ilerleme çubuğu** ekle
- "Olta Kurdusu olmana **135 puan** kaldı" → Çubuk %72 dolu göster
- Çubuğun altında: "Bir mera paylaşırsan 50 puan kazanırsın!" — bir sonraki kolay eylemi öner

**D — Mera Paylaşım Teşviki:**
```
✅ "Bu mera gizli kalacak — sadece arkadaşların görecek"
✅ "Mera paylaşırsan 50 puan kazanırsın"
✅ "Daha fazla yer paylaşırsan daha fazla insanın paylaşımlarını görebilirsin"
```
Karşılıklılık ilkesini net anlat — "sen verirsen sen de alırsın."

**E — Check-in Onayı:**
- Başarılı check-in sonrası büyük tik animasyonu ✅
- "+15 PUAN" büyük ve altın rengi
- "Mera sahibine haber verdik" — eylemin sosyal etkisini anlat
- "Buraya 3 kez bildirim yaparsan oy artacak" — gamifikasyon ipucu ver ama sade

**F — VIP Mera Kilidi:**
```
❌ Kötü: [Kilitli ikon] "Bu içerik Usta rütbesi gerektirir"
✅ İyi:  🔒 "Bu gizli merayı görmek için 750 puanın daha olması lazım.
         Mera paylaşarak veya balık bildirimi göndererek puan kazanabilirsin."
```
Engeli göster ama yolu da göster. Kaç puanı kaldığını söyle, ne yapması gerektiğini söyle.

**G — Gölge Puan (Implement Edilince):**
```
✅ "📍 Safi Reis, senin paylaştığın İstinye İskelesi'ne gitti!
   +20 Puan kazandın — paylaşımın işe yaradı! 🙏"
```
Kimin sayesinde puan kazandığını söyle — sosyal bağ ve takdir duygusu oluşturur.

**H — Mera Muhtarlığı:**
```
✅ "👑 Bu ay Sirkeci Balık Tezgahı merasının Muhtarısın!
   En doğru raporları sen gönderdin."
```
Unvan bildirimini öne çıkar, puan yerine "sorumluluk" ve "güven" vurgusu yap — hedef kitle bu değeri anlıyor.

**I — Sürdürülebilirlik Puanı:**
```
✅ "🌿 Balığı salarak doğayı korudun! +40 Doğayı Koru Puanı"
   "Denizlerimize katkın için teşekkürler."
```
Çevre duyarlılığı 45+ yaş kitlede (balıkçılık geleneği bilinci) iyi karşılanır.

---

## 4. Özet — Teknik Öncelik Sıralaması

| Öncelik | Konu | Durum | Aciliyet |
|---------|------|-------|----------|
| 🔴 Kritik | `shadow-point-calculator` Edge Function'ı implement et | Eksik | MVP sonrası Sprint |
| 🔴 Kritik | `checkins` tablosuna günlük rate-limit kısıtı ekle (spam önlemi) | Eksik | Hemen |
| 🟠 Yüksek | Mera Muhtarlığı otomatik atama cron'u implement et | Eksik | Sonraki Sprint |
| 🟠 Yüksek | `shadow_points` UNIQUE kısıtı ile Sybil saldırısını engelle | Eksik | EF yazılmadan önce |
| 🟠 Yüksek | `checkin_verified` kaynak kaynağının (EXIF) yerine geçecek doğrulama mekanizması belirle | Belirsiz | Tasarım kararı |
| 🟡 Orta | VIP erişim için minimum mera sayısı şartı getir | Eksik | Sonraki Sprint |
| 🟡 Orta | Koordinat bulanıklaştırma katmanı (VIP kilitli meralar için yaklaşık pin) | Eksik | UX iyileştirmesi |
| 🟢 Düşük | Rütbe arası motivasyon rozetleri (1000 puan "Tecrübeli Balıkçı") | Tasarım eksik | Gelecek faz |
| 🟢 Düşük | "Katkı/Tüketim oranı" profil metriği | Tasarım eksik | Gelecek faz |

---

*Bu rapor kaynak kodu analizi ve oyunlaştırma/UX best practice'leri baz alınarak hazırlanmıştır. Herhangi bir kod değişikliği içermez.*
