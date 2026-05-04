# Konum Servisleri, Harita Performansı ve Batarya Optimizasyonu Analizi

> **Tarih:** 04 Mayıs 2026  
> **Analiz Edilen Dosyalar:** `location_service.dart`, `proximity_vote_service.dart`, `map_screen.dart` (2367 satır), `spot_repository.dart`, `istanbul_weather_provider.dart`, `connectivity_provider.dart`, `pubspec.yaml`, `ARCHITECTURE.md`, `MVP_PLAN.md`  
> **Kapsam:** Kod değişikliği yok — salt performans ve pil tüketimi analizi  
> **Risk Seviyeleri:** 🔴 Kritik | 🟠 Yüksek | 🟡 Orta | 🟢 Düşük/İyi

---

## 1. Konum (GPS) Stratejisi ve Pil Sömürüsü

### 1.1 GPS Hassasiyet Analizi — Tüm Kullanım Noktaları

GPS, uygulamada **yalnızca `getCurrentPosition` (tek seferlik sorgu)** ile kullanılıyor; sürekli `getPositionStream` akışı yok. Bu temel olarak doğru bir tasarım ✅

Aşağıdaki tabloda konum alınan her noktanın hassasiyet seviyesi belgelenmiştir:

| Kullanım Noktası | Dosya | Hassasiyet | Tetikleyici |
|-----------------|-------|-----------|------------|
| `LocationService.getCurrentPosition()` | `location_service.dart:23` | `LocationAccuracy.high` | Tüm çağrılar için ortak |
| Harita "Konumum" butonu | `map_screen.dart:348` | `high` (servisten) | Kullanıcı butona basar |
| Arama "En Yakın" sıralama | `map_screen.dart:463` | `high` (servisten) | Arama çubuğuna odaklanınca |
| Mera Ekleme koordinat alma | `add_spot_screen.dart:96` | `high` (servisten) | Kullanıcı "Konumumu Kullan" basar |
| Check-in konum doğrulama | `checkin_screen.dart:229` | `high` (servisten) | "Buraya Geldim" butonu |
| ProximityVoteService | `proximity_vote_service.dart:40` | `LocationAccuracy.high` | Harita yüklenince çağrılıyor |

---

### 1.2 🟠 YÜKSEK — Tek Hassasiyet (`high`) Her Senaryo İçin Kullanılıyor

`LocationService.getCurrentPosition()` tüm çağrı noktaları için **global `LocationAccuracy.high`** sabitini kullanıyor. Bu, farklı senaryoların ihtiyacına bakmaksızın her konum isteğinde maksimum GPS donanım kaynağı tüketiliyor.

**Senaryo bazlı gerçek ihtiyaç analizi:**

| Senaryo | Gerçek Hassasiyet İhtiyacı | Şu Anki Hassasiyet | Fark |
|---------|---------------------------|-------------------|------|
| Check-in (500m kural) | `best` veya `high` | `high` | ✅ Uygun |
| Mera ekleme (koordinat) | `high` | `high` | ✅ Uygun |
| "Konumum" harita butonu | `medium` (şehir/mahalle) | `high` | ⚠️ Fazla |
| Arama "En Yakın" sıralama | `low` (bölge bazlı) | `high` | ⚠️ Fazla |
| ProximityVoteService | `medium` (500m çap yeterli) | `high` | ⚠️ Fazla |

**Batarya Etkisi:**  
`LocationAccuracy.high` her çağrıda GPS donanımını tam güçte uyandırır. GPS cold start (uyku sonrası) 1-3 saniye alır ve bu sürede radyo aktif kalır. Arama çubuğuna her dokunulduğunda `getCurrentPosition(high)` çağrılması, kullanıcı 3 kez arama alanına odaklanırsa 3 × GPS uyanıklığı demektir.

**Öneri (Dinamik Hassasiyet Stratejisi):**
```dart
// Önerilen: context-aware hassasiyet
enum LocationPurpose { checkin, mapCenter, search, spotAdd }

LocationAccuracy _accuracyFor(LocationPurpose purpose) => switch (purpose) {
  LocationPurpose.checkin  => LocationAccuracy.best,     // 500m kural kritik
  LocationPurpose.spotAdd  => LocationAccuracy.high,     // mera koordinatı önemli
  LocationPurpose.mapCenter => LocationAccuracy.medium,  // harita merkezi için yeterli
  LocationPurpose.search   => LocationAccuracy.low,      // bölge sıralaması için yeterli
};
```

---

### 1.3 ✅ İYİ — Sürekli GPS Akışı (Stream) Yok

`getPositionStream()` uygulamanın hiçbir yerinde kullanılmıyor. Konum sadece kullanıcı eyleminde tek seferlik alınıyor. Bu, pil açısından ideal tasarım. ✅

---

### 1.4 ✅ İYİ — Arka Plan GPS Sızdırması Yok

`map_screen.dart` dispose() metodu tüm Timer ve Realtime kanalları kapatıyor:
```dart
void dispose() {
  unawaited(_checkinsRealtimeChannel?.unsubscribe());  // ✅
  _checkinPollTimer?.cancel();                         // ✅
  _boundsDebounce?.cancel();                           // ✅
  _checkinRealtimeDebounce?.cancel();                  // ✅
  ...
}
```

Uygulama arka plana alındığında Flutter yaşam döngüsü widget tree'yi kaldırmaz ama timer'lar UI thread'e bağlı olduğundan yavaşlar. GPS stream olmadığı için arka planda sessiz GPS tüketimi riski yok. ✅

---

### 1.5 🟡 ORTA — ProximityVoteService Her Harita Açılışında GPS Çağrısı Yapıyor

`ProximityVoteService.checkAndShowVoteDialog()` haritadan çağrılıyor. Bu servis içinde:
1. `Geolocator.checkPermission()` → OS çağrısı
2. `Geolocator.getCurrentPosition(high)` → GPS uyanışı
3. Supabase'ten aktif check-in listesi → ağ isteği
4. Her check-in için mera koordinat sorgusu → N×1 Supabase sorgu

Bu zincir, kullanıcı harita sekmesine her geçişinde tetikleniyor. Eğer uygulama zaten açıksa ve sekme değiştirme sık olursa bu zincir gereksiz yere tekrar çalışır.

**Öneri:** Son çalışma zamanını kaydet; X dakika içinde tekrar sorma:
```dart
DateTime? _lastProximityCheck;
if (_lastProximityCheck != null &&
    DateTime.now().difference(_lastProximityCheck!) < const Duration(minutes: 5)) return;
```

---

## 2. Harita Render Performansı ve Hafıza Yönetimi

### 2.1 ✅ İYİ — Tile Caching ve Network Optimize Edilmiş

`flutter_map` konfigürasyonu:
```dart
CancellableNetworkTileProvider()  // ✅ hızlı zoom'da gereksiz indirmeleri iptal eder
keepBuffer: 8  // ✅ Önceki zoom seviyesinin tile'larını 8 satır tutar
panBuffer: 3   // ✅ Kaydırma sırasında 3 tile önceden yüklenir
tileDisplay: TileDisplay.instantaneous()  // ✅ Anında gösterim, solma animasyonu yok (CPU tasarrufu)
```

`CancellableNetworkTileProvider` sayesinde hızlı zoom değişiminde sunucuya giden tamamlanmamış tile istekleri iptal ediliyor — hem ağ trafiği hem CPU korunuyor. ✅

**Potansiyel sorun:** `keepBuffer: 8` ile 8 satır tile, her zoom seviyesinde 256×256px tile'lardan oluşuyor. Çift tile katmanı (Imagery + Boundaries) ile bu iki katına çıkıyor. Düşük RAM'li cihazlarda (2GB altı) çok panning sonrasında tile cache bellek baskısı yaratabilir.

**Öneri:** `keepBuffer: 4` orta yol olarak test edilebilir; çoğu kaydırma senaryosunda görsel fark minimal.

---

### 2.2 ✅ İYİ — Marker Clustering Aktif

`MarkerClusterLayerWidget` haritada mevcut ve yapılandırılmış:
```dart
MarkerClusterLayerWidget(
  options: MarkerClusterLayerOptions(
    markers: _buildMarkers(),
    maxClusterRadius: 58,   // 58 piksel içindeki pinler gruplanır
    size: const Size(42, 42),
    builder: (context, markers) { ... },  // sayı rozeti gösterir
  ),
)
```

Yüzlerce mera pin'i yerine zoom'a göre kümeler gösteriliyor. Bu harita ekranındaki en kritik performans optimizasyonu. ✅

---

### 2.3 🟠 YÜKSEK — `_buildMarkers()` Her setState'te Yeniden Çalışıyor

```dart
if (_showSpots)
  MarkerClusterLayerWidget(
    options: MarkerClusterLayerOptions(
      markers: _buildMarkers(),  // ← her setState'te çağrılıyor
      ...
    ),
  )
```

`_buildMarkers()` metodu 500 meradan `List<Marker>` üretiyor. Bu liste `build()` metodu her çağrıldığında **sıfırdan yeniden oluşturuluyor.** Harita kaydırıldığında (her pixel değişiminde) `onPositionChanged` tetikleniyor:

```dart
onPositionChanged: (camera, _) {
  final crossedThreshold = (_currentZoom > 13) != (z > 13);
  _currentZoom = z;
  if (crossedThreshold && mounted) setState(() {});  // ← threshold geçince rebuild
  if (z >= 10.5) _scheduleBoundsSpotsFetch();
},
```

`setState(() {})` çağrısı tüm `build()` ağacını yeniden çizdiriyor; `_buildMarkers()` 500 marker için yeniden çalışıyor.

**Tespit:** Threshold kontrolü sayesinde her pixel kaydırmada değil, yalnızca zoom 13 eşiği geçilince rebuild tetikleniyor. Bu iyi bir optimizasyon ✅. Ancak `_refreshActiveCheckins()` sonrasında da `setState` çağrılıyor — bu, check-in gerçek zamanlı güncellemelerinde 500 marker'lık listeyi yeniden üretiyor.

**Öneri:** `_buildMarkers()` sonucunu state değişkeninde cache'le; sadece `_spots` veya `_activeCheckinsBySpotId` değişince yeniden hesapla:
```dart
List<Marker>? _cachedMarkers;
List<SpotModel>? _lastMarkerSpots;

List<Marker> get _markers {
  if (_cachedMarkers != null && _lastMarkerSpots == _spots) return _cachedMarkers!;
  _cachedMarkers = _buildMarkers();
  _lastMarkerSpots = _spots;
  return _cachedMarkers!;
}
```

---

### 2.4 🟡 ORTA — Çift TileLayer Render Yükü

Haritada iki ayrı `TileLayer` render ediliyor:
1. **Imagery Layer:** ArcGIS Dünya Görüntüsü (uydu fotoğraf)
2. **Boundaries Layer:** ArcGIS Sınır ve Yer Adları (vektör overlay)

İki katman, tile başına 2× GPU texture upload + composite maliyeti demek. Düşük-orta segment Android cihazlarda (Adreno 306, Mali-T720) harita kayarken frame drop yaşanabilir.

**Değerlendirme:** İki katman görsel açıdan kaliteli bir uydu haritası sunuyor; bu tasarım kararı bilinçli. Orta segment cihazlar için "basit harita modu" seçeneği gelecek fazda düşünülebilir.

---

### 2.5 ✅ İYİ — RepaintBoundary ile Harita İzole Edilmiş

```dart
Positioned.fill(
  child: RepaintBoundary(  // ✅
    child: FlutterMap( ... ),
  ),
),
```

Harita widget'ı `RepaintBoundary` içinde — üstündeki arama kutusu, hava kartı veya sheet değişince harita katmanı yeniden boyanmıyor. Bu kritik bir performans önlemi. ✅

---

## 3. State Yönetimi ve Gereksiz Yeniden Çizimler

### 3.1 ✅ İYİ — Hava Durumu Saatlik Poll, Sürekli Sorgu Değil

`IstanbulWeatherNotifier`:
```dart
void _scheduleHourlySupabasePoll() {
  final now = DateTime.now();
  final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
  _pollTimer = Timer(nextHour.difference(now), () {
    unawaited(_silentReload());
    _scheduleHourlySupabasePoll();
  });
}
```

Hava durumu verisi bir sonraki tam saate kadar bekler, ardından Supabase cache'ten sessizce güncellenir. Open-Meteo'ya istemci tarafından istek yok. CPU açısından ideal. ✅

`ref.onDispose(() => _pollTimer?.cancel())` ile dispose düzgün yönetiliyor. ✅

---

### 3.2 🟡 ORTA — Realtime Checkin Debounce İyi Ama setState Tetikleyicisi Geniş

Realtime check-in güncelleme mekanizması:
```dart
void _scheduleDebouncedCheckinRefresh() {
  _checkinRealtimeDebounce?.cancel();
  _checkinRealtimeDebounce = Timer(const Duration(milliseconds: 450), () {
    if (mounted) unawaited(_refreshActiveCheckins());
  });
}
```

450ms debounce mekanizması "check-in yağmurunda" art arda setState döngüsünü önlüyor — doğru. ✅

Ancak `_refreshActiveCheckins()` tamamlandığında:
```dart
_postFrameSetState(() => _activeCheckinsBySpotId = grouped);
```

Bu, tam harita ekranını (2367 satır) yeniden build ediyor. `_activeCheckinsBySpotId` içinde sadece 1-2 mera değişmiş olabilir ama tüm `build()` metodu çalışıyor. Riverpod ile bu state parçalanabilir ve sadece ilgili widget'lar rebuild olur — ancak `MapScreen` şu an `StatefulWidget` olduğundan tüm state tek `setState` ile yönetiliyor.

---

### 3.3 🟡 ORTA — `connectivityProvider` Her Rebuild'de Dinleniyor

`MapScreen` içinde:
```dart
Consumer(
  builder: (context, ref, _) {
    final count = ref.watch(unreadCountProvider);
    final onlineAsync = ref.watch(connectivityProvider);
    ...
  }
)
```

`Consumer` ile sadece bildirim/bağlantı değişince rebuild sınırlandırılmış — doğru ✅. Ancak `connectivityProvider` bir `StreamProvider` ve `onConnectivityChanged` stream'i; her bağlantı olayında `Consumer` yeniden build oluyor. Bu düşük frekanslı bir event olduğundan gerçek hayatta sorun yaratmıyor.

---

### 3.4 🟡 ORTA — `_loadNearestSpotsForSearch()` Arama Kutusuna Her Odaklanmada GPS İstiyor

```dart
onTap: () => _onSearchChanged(_searchController.text),
```

Kullanıcı arama kutusuna dokunduğunda `_onSearchChanged('')` çağrılıyor; bu da `_loadNearestSpotsForSearch()` → `LocationService.getCurrentPosition(high)` tetikliyor. Kullanıcı arama kutusunu kapatıp tekrar açarsa GPS yeniden uyanıyor.

**Öneri:** Son konum sonucunu 60 saniye cache'le:
```dart
Position? _cachedSearchPos;
DateTime? _searchPosTime;

Future<Position?> _getSearchPosition() async {
  if (_cachedSearchPos != null &&
      _searchPosTime != null &&
      DateTime.now().difference(_searchPosTime!) < const Duration(seconds: 60)) {
    return _cachedSearchPos;
  }
  final pos = await LocationService.getCurrentPosition();
  _cachedSearchPos = pos;
  _searchPosTime = DateTime.now();
  return pos;
}
```

---

### 3.5 Drift (SQLite) Yerel Önbellek — Batarya Dostu ✅

`SpotRepository.getCachedSpots()` Drift ORM ile SQLite'a yazıp okuyor. Ağ kesintisinde yerel cache devreye giriyor:
```dart
final cached = await _repository.getCachedSpots();
```
Offline çalışma, ağ isteği sayısını azaltır → batarya için olumlu ✅

---

## 4. 45+ Yaş Amca Batarya Anksiyetesi — UX Stratejisi

### 4.1 Hedef Kitlenin Batarya Davranışı

45+ yaş balıkçıların tipik davranış kalıpları:
- Şarj %40'ın altına düştüğünde uygulamayı kapatmaya veya düşük performans moduna geçmeye eğilimli
- "Harita açık mı, GPS tüketim yapıyor mu?" kaygısı
- Gün boyunca çıkışta pil tasarrufu öncelikli
- "Şu uygulamayı açık bıraktım, pilim neden bitti?" düşüncesi

### 4.2 Güven Veren UX Mesajları — Somut Öneriler

**A — Harita Butonu "GPS Durumu" Geri Bildirimi:**  
Mevcut: Butona basınca GPS alınıyor, sessizce oluyor.  
Öneri: Buton tıklanınca kısa bir "📍 Konum alınıyor..." snackbar göster, alındıktan sonra otomatik kapansın. Kullanıcı GPS'in "bir kez kullanılıp kapandığını" hisseder.

```
✅ "📍 Konumun bulundu, harita ayarlandı."
(2 sn sonra kaybolur)
```

**B — Uygulama İlk Açılışta GPS İzni Konuşması:**  
Mevcut: İzin diyaloğu OS varsayılanı — teknik ve soğuk.  
Öneri — Onboarding'de izin öncesi açıklama:

> "🎣 Uygulamayı kapadığında GPS duruyor.
> Balık yerini bulmak için sadece butona bastığında konumunu bir kez alıyoruz.
> Şarjını yemiyor."

**C — Ayarlar Ekranında "Uygulama Pil Dostu" Rozeti:**

```
🔋 Pil Dostu Uygulama
Arka planda GPS kullanmaz.
Harita sadece açıkken çalışır.
```

Bu mesaj hem güven verir hem "neden pil bitmiyor" sorusunu önceden yanıtlar.

**D — Harita Yüklenme Animasyonu:**  
Karmaşık lottie animasyonu yerine sade bir progress indicator. Yükleme hızlı hissettirirse kullanıcı "bunun pilimi yemediğini" düşünür.

**E — "Düşük Güç Modu" Uyarısı (İleri Faz):**  
Cihaz bataryası %20 altına düştüğünde `battery_plus` paketi ile tespit edilip bildirim:

```
🔋 Şarjın azalıyor.
Harita güncellemelerini yavaşlattık, pilini koruyoruz.
[Tamam]
```

Bu tamamen psikolojik güven veren bir mesaj — kullanıcı "uygulama benim için düşünüyor" hisseder.

---

## 5. Özet — Öncelik Sıralaması

| # | Bulgu | Önem | Tip |
|---|-------|------|-----|
| 1 | Arama kutusu odaklanmasında GPS(high) çağrısı | 🟠 Yüksek | Pil tüketimi |
| 2 | `_buildMarkers()` her setState'te 500 marker yeniden üretiliyor | 🟠 Yüksek | CPU/RAM |
| 3 | `ProximityVoteService` her harita açılışında GPS + N×DB sorgusu | 🟡 Orta | Pil + ağ |
| 4 | Harita "Konumum" butonu için `high` hassasiyet, `medium` yeterli | 🟡 Orta | Pil tüketimi |
| 5 | Çift TileLayer düşük-segment GPU'larda frame drop riski | 🟡 Orta | Render |
| 6 | Son konum sonucunun cache'lenmemesi (tekrar GPS isteği) | 🟡 Orta | Pil tüketimi |
| 7 | Tile cache'te `keepBuffer: 8` RAM yükü | 🟢 Düşük | RAM |
| 8 | GPS stream kullanılmıyor — tek seferlik sorgu | ✅ İyi | Tasarım |
| 9 | Dispose'da tüm timer/stream doğru kapatılıyor | ✅ İyi | Bellek |
| 10 | Hava durumu saatlik poll, sürekli sorgu değil | ✅ İyi | Pil |
| 11 | RepaintBoundary ile harita izole edilmiş | ✅ İyi | Render |
| 12 | MarkerClusterLayerWidget aktif | ✅ İyi | Render |
| 13 | Drift yerel cache — offline çalışma | ✅ İyi | Ağ/Pil |

---

*Bu rapor kaynak kodu ve Flutter/Dart mobil performans best practice'leri baz alınarak hazırlanmıştır. Herhangi bir kod değişikliği içermez.*
