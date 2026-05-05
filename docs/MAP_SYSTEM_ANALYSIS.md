# Harita Altyapısı, Konum, Render Takılmaları ve Çevrimdışı Performans Analizi

Bu rapor, Balıkçı uygulamasının (v1.0.0+2) harita altyapısı, performans takılmaları, çevrimdışı kapasitesi ve kullanıcı deneyiminin (özellikle 45+ yaş profili) derinlemesine analizini sunmaktadır.

---

## 1. Harita Altyapısı (Infrastructure) ve Konfigürasyon

- **Teknoloji Yığını:** Projede modern ve stabil paketler tercih edilmiş (`flutter_map: 7.0.2`). Tile sağlayıcı olarak OpenStreetMap yerine doğrudan yüksek kaliteli ArcGIS uydu görüntüleri (`World_Imagery`) ve referans haritaları (`World_Boundaries_and_Places`) katman katman eklenmiş. Bu dizilim (iki ayrı katman olarak) modern harita standartlarına son derece uygun ve detaylı bir görsellik sunuyor.
- **Cancellable Tiles:** Harita tile altyapısında `flutter_map_cancellable_tile_provider` paketi (3.0.2 versiyonu) doğru biçimde entegre edilmiş. `TileLayer` bileşenlerinde `tileProvider: _mapTileProvider` olarak tanımlanan bu özellik, kullanıcının haritada hızla kaydırma yaptığı (pan) ya da ani zoom in/out yaptığı anlarda iptal edilen ekran bölgeleri için başlatılmış eski HTTP ağ isteklerini gerçekten kesiyor. Bu mekanizma olası bir ağ darboğazını (network bottleneck) başarılı bir şekilde önlüyor. Ayrıca `keepBuffer: 4` ve `panBuffer: 3` değerleri verilerek, "beyaz karelerin" (flickering) yüklenme esnasında en aza indirgenmesi sağlanmış.

## 2. Takılmalar (Lag), Büyütme/Küçültme (Zoom/Pan) Performansı ve Veri Çekme

- **Kasma / Frame Drop Analizi:** Uygulamadaki 60FPS/120FPS render akıcılığını tehlikeye atan en büyük unsur harita kaydırma sırasında oluşan gereksiz `setState` (widget yeniden çizimi) işlemleridir. Kod mimarisinde `MapOptions.onPositionChanged` tetikleyicisine bakıldığında bu tuzağa düşülmediği görülüyor. Yalnızca belirli bir zoom eşiği aşıldığında (`_currentZoom > 13 != z > 13`) `setState` tetikleniyor. Bunun dışında `_cachedMarkers` yardımıyla liste referansına göre marker cache'lemesi yapılmış. Bu nedenle haritada pan yapılırken arayüzde donma ve kasılmalar yaşanmaz, CPU/GPU kullanımı optimize edilmiştir.
- **Bounding Box (Görüş Alanı) ve Veri Çekme:** Veritabanından verilerin nasıl çekildiği performansı doğrudan etkiler. Kodda iki katmanlı güvenli bir mimari tercih edilmiş. Harita ilk açıldığında `getSpots(limit: 500)` ile yakın/genel bir başlangıç paketi indiriliyor. Ancak harita hareket ettikçe, `_scheduleBoundsSpotsFetch()` fonksiyonu içindeki `_boundsDebounce` ile 520ms'lik bir bekleme (debounce) süresinden sonra yalnızca görüş alanına giren sınırlar (Bounding Box - PostGIS türevi koordinat aralığı) Drift'ten veya Supabase'den çekiliyor. Bu sayede tüm Türkiye'yi RAM'e yükleme problemi ortadan kalkmış.
- **Marker Clustering (Gruplama):** `flutter_map_marker_cluster` entegrasyonu (v1.4.0) başarıyla sağlanmış. Ekranda yüzlerce mera pin'i olduğunda dahi performans kaybı en aza indirgeniyor.

## 3. Çevrimdışı (Offline) Harita ve Tile Yönetimi

- **Tile Caching (Önbellekleme):** Sistem, ağ varken indirdiği tile'ları RAM üzerinde (`keepBuffer: 4`) önbelleğe alıyor. Ancak kullanıcının denizde interneti tamamen kaybettiği durumlar için **kalıcı bir SQLite tabanlı tile disk cache'i bulunmuyor**. Mimari belgesinde (`docs/ARCHITECTURE.md`) bu durum net olarak "Kalıcı offline tile cache (pubspec’te yok; H12’de planlı)" şeklinde teknik bir borç olarak ifade ediliyor. Mevcut haliyle daha önce gezilmeyen veya RAM'den düşen koordinatlara denizdeyken gidildiğinde harita arka planı görünmeyecektir.
- **Offline Mera Gösterimi:** Mera gösterimi offline senaryolara oldukça dayanıklı bir mimariyle kurgulanmış. `_loadSpots` sürecinde uzak veri kaynağında sorun çıktığında (internet yokken vs.), anında catch bloğuna girip `_repository.getCachedSpots()` (Drift local veritabanı) ile önceden senkronlanmış meralar anında gösteriliyor. Offline deneyimde mera pinleri kaybolmuyor.

## 4. 45+ Yaş Amca UX/UI (Harita Deneyimi)

- **Dokunma Hedefleri (Touch Targets):** `SpotMarker` bileşeninin boyutu `56x56 dp` olarak ayarlanmış. Kalın parmaklı ve ekranı zor gören 45+ yaş profiline uygun olarak, mobil erişilebilirlik standartlarının (min 48x48 dp) üzerinde, isabetli dokunuşlara (no-miss) olanak sağlayan bir büyüklüğe sahip.
- **Pin Yoğunluğu ve Anlaşılırlık:** Gizlilik seviyelerine göre (Public, Friends, Private, VIP) meraların birbirinden görsel olarak farklılaşması için Teal, Mavi, Gri ve Altın Sarısı gibi ayrımlar yapılmış (`AppColors`). Ayrıca rütbe yetersizse pinler üzerinde "🔒" (kilit) emojisi gösterilip tıklanabilir ama işlem yapılamaz hissiyatı verilmesi anlaşılırlığı güçlendirmiş.
- **Konumumu Bul Butonu ve GPS Geri Bildirimi:** "Konumuma Git" metodunda (`_goToMyLocation`) teknik olarak bir eksik (veya UX problemi) mevcut. Fonksiyon çağrıldığında `LocationService.getCurrentPosition` ile GPS aranmaya başlanıyor ancak bu asenkron bekleme sırasında ekrana hiçbir yükleme (loading indicator) geribildirimi verilmiyor. Cihaz GPS fix bulana dek (bu saniyeler sürebilir) arayüzde bir tepki olmadığı için, sabırsız 45+ kullanıcılar butona defalarca basabilir ve cihazı kilitlenmiş hissedebilir. GPS aranırken ekrana bir loader dönmesi gerekir.

## 5. Deep Linking ve Harita Etkileşimi

- **Bildirimden Haritaya (Deep Linking):** Kullanıcı "Favori meranda balık var!" gibi bir push bildirime dokunduğunda uygulama `MapScreen(initialSpotId: spotId)` formatında açılıyor ve `_openInitialSpotIfNeeded()` tetikleniyor. İşlevsel açıdan haritayı meraya ortalıyor ve `_sheetController.animateTo` yardımıyla alt paneli (BottomSheet) otomatik açıyor.
- **Race Condition ve Durum Bozulmaları Riskleri:** Bildirim tıklandığında mera listesinin `_spots` içerisine yüklenmesi zaman alabiliyor. `_openInitialSpotIfNeeded` metodu çalışırken eğer `initialSpotId`'ye sahip olan mera ilk 500 limitinde veya local cache'de anında yüklenmişse sistem kusursuz işler. Fakat bildirimle gelen spot çok uzak bir konumdaysa ve ilk 500'de yoksa, harita API'si `spot`'u bulamayacağından (silent catch bloğuna düştüğünden) mera açılmaz ve odaklanmaz. Bu durumda deep linking sekteye uğrar. Bu akışta `initialSpotId` için doğrudan spesifik bir GET isteği (`getSpotById`) ile haritayı ortalama garanti altına alınmalıdır.
