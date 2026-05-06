import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/core/services/map_cache_service.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/geo_utils.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/core/utils/mera_weather_display.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/models/shop_model.dart';
import 'package:balikci_app/features/map/widgets/spot_marker.dart';
import 'package:balikci_app/features/map/widgets/weather_card.dart';
import 'package:balikci_app/data/repositories/shop_repository.dart';
import 'package:balikci_app/data/repositories/user_repository.dart';
import 'package:balikci_app/shared/providers/connectivity_provider.dart';
import 'package:balikci_app/shared/providers/favorite_provider.dart';
import 'package:balikci_app/shared/providers/notification_provider.dart';

/// Harita ekranı — H3 temel implementasyon.
class MapScreen extends StatefulWidget {
  /// Bildirimden gelince doğrudan açılacak mera kimliği.
  final String? initialSpotId;

  const MapScreen({super.key, this.initialSpotId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SpotRepository _repository = SpotRepository();
  final CheckinRepository _checkinRepository = CheckinRepository();
  final ShopRepository _shopRepository = ShopRepository();
  final MapController _mapController = MapController();

  /// Hızlı zoom’da gereksiz indirmeleri iptal eder; beyaz kareleri azaltır.
  final CancellableNetworkTileProvider _mapTileProvider =
      CancellableNetworkTileProvider();

  /// FMTC tile cache başarıyla başlatıldıysa true; yoksa fallback provider kullanılır.
  bool _fmtcReady = false;

  List<SpotModel> _spots = const [];

  /// Uzak `getSpots` + `getSpotsInBounds` birleşimi (kimlik bazlı).
  final Map<String, SpotModel> _spotMap = {};
  List<ShopModel> _shops = const [];
  Map<String, List<CheckinModel>> _activeCheckinsBySpotId = const {};
  bool _isLoading = true;
  String? _error;

  /// GPS aranırken true — buton devre dışı kalır ve spinner gösterilir.
  bool _isLocating = false;

  /// Bildirim deep-link'inden gelen mera Supabase'den çekilirken true.
  /// Haritanın üstünde geçici bir yükleme banner'ı gösterir.
  bool _isDeepLinkLoading = false;

  bool _showShops = false;
  bool _showSpots = true;

  bool _checkinRefreshInFlight = false;
  bool _checkinRefreshQueued = false;
  Timer? _checkinPollTimer;
  Timer? _boundsDebounce;
  Timer? _checkinRealtimeDebounce;
  RealtimeChannel? _checkinsRealtimeChannel;

  SpotModel? _sheetSpot;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Açık mera sheet’i için detaylı check-in isteği — eski cevapları yok say.
  int _sheetDetailEpoch = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SpotModel> _searchResults = const [];

  /// Arama konumu cache — 60 s içinde GPS'i tekrar uyandırmaz.
  Position? _cachedSearchPos;
  DateTime? _cachedSearchPosTime;

  /// Marker cache — _spots veya _activeCheckinsBySpotId değişince geçersizleşir.
  List<Marker>? _cachedMarkers;
  Object? _markersCacheKey;

  MeraWeatherSnapshot? _meraWeather;
  bool _weatherLoading = false;

  double _currentZoom = 10;

  /// Geçerli kullanıcının rütbesi — VIP pin kilidi için kullanılır.
  /// 'acemi' | 'olta_kurdu' | 'usta' | 'deniz_reisi'
  String _currentUserRank = 'acemi';

  /// Geçerli kullanıcının toplam puanı — VIP kilitli sheet'te ilerleme çubuğu için.
  int _currentUserScore = 0;

  bool get _isUstaOrAbove =>
      _currentUserRank == 'usta' || _currentUserRank == 'deniz_reisi';

  @override
  void initState() {
    super.initState();
    _initializeCacheAndLoad();
    _fetchCurrentUserRank();
    _checkFmtcReady();
    unawaited(MapCacheService.evictOldTiles());
  }

  Future<void> _checkFmtcReady() async {
    try {
      final ready =
          await FMTCStore(AppConstants.fmtcStoreName).manage.ready;
      if (mounted && ready) setState(() => _fmtcReady = true);
    } catch (_) {
      // FMTC başlatılmadıysa sessizce fallback provider'a geçilir.
    }
  }

  /// FMTC hazırsa cache provider, değilse CancellableNetworkTileProvider döner.
  /// Exception build() metodunu kırmaz.
  TileProvider _buildTileProvider() {
    try {
      if (_fmtcReady) {
        return FMTCStore(AppConstants.fmtcStoreName).getTileProvider(
          settings: FMTCTileProviderSettings(
            behavior: CacheBehavior.cacheFirst,
            cachedValidDuration:
                Duration(days: AppConstants.fmtcMaxCacheDays),
          ),
        );
      }
    } catch (e) {
      debugPrint('FMTC provider hatası: $e');
    }
    return _mapTileProvider;
  }

  @override
  void dispose() {
    unawaited(_checkinsRealtimeChannel?.unsubscribe());
    _checkinsRealtimeChannel = null;
    _checkinPollTimer?.cancel();
    _boundsDebounce?.cancel();
    _checkinRealtimeDebounce?.cancel();
    _sheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeCacheAndLoad() async {
    await _loadSpots();
    await _loadShops();
    _startCheckinsRealtime();
    // await ile çağırıyoruz: _openInitialSpotIfNeeded artık async ve
    // deep-link yüklemesini kendisi yönetiyor.
    await _openInitialSpotIfNeeded();
  }

  Future<void> _fetchCurrentUserRank() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile = await UserRepository().getProfile(uid);
      if (mounted && profile != null) {
        setState(() {
          _currentUserRank = profile.rank;
          _currentUserScore = profile.totalScore;
        });
      }
    } catch (_) {
      // Rütbe alınamazsa 'acemi' varsayılanı kalır — VIP pinler kilitli görünür.
    }
  }

  /// Bildirim deep-link'inden gelen [initialSpotId] varsa merayı açar.
  ///
  /// Akış:
  ///   1. Önce bellek içi [_spots] listesine bakar — varsa anında seçer.
  ///   2. Yoksa Supabase'den tekil olarak çeker, [_spotMap]'e ekler,
  ///      haritayı konuma kaydırır ve BottomSheet'i açar.
  ///   3. Mera silinmiş/gizlenmişse kullanıcıya anlaşılır bir SnackBar gösterir.
  Future<void> _openInitialSpotIfNeeded() async {
    final targetId = widget.initialSpotId;
    if (targetId == null) return;

    // --- 1. Önce mevcut bellek listesini kontrol et ---
    final cached = _spots.where((s) => s.id == targetId).firstOrNull;
    if (cached != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectSpot(cached);
      });
      return;
    }

    // --- 2. Cache miss: Supabase'den çek ---
    if (!mounted) return;
    setState(() => _isDeepLinkLoading = true);

    try {
      final spot = await _repository.getSpotById(targetId);
      if (!mounted) return;

      if (spot == null) {
        // Mera Supabase'de de yok — silinmiş veya gizlenmiş.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu mera artık mevcut değil veya gizlenmiş olabilir. '  
              'Başka bir mera seçebilirsin.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // --- 3. Yeni merayı harita state'ine dahil et ---
      _spotMap[spot.id] = spot;
      setState(() => _spots = _spotMap.values.toList());

      // --- 4. Haritayı konuma kaydır ve sheet'i aç ---
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(LatLng(spot.lat, spot.lng), 15);
        } catch (_) {
          // Harita henüz hazır değilse görmezden gel.
        }
        _selectSpot(spot);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mera bilgisi yüklenirken bir sorun oluştu. '  
            'İnternet bağlantını kontrol edip tekrar dene.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeepLinkLoading = false);
    }
  }

  /// `checkins` tablosunu gerçek zamanlı dinle.
  /// INSERT / UPDATE / DELETE gelince haritadaki check-in sayaçları güncellenir.
  void _startCheckinsRealtime() {
    _checkinsRealtimeChannel?.unsubscribe();
    _checkinsRealtimeChannel = SupabaseService.client
        .channel('public:checkins')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'checkins',
          callback: (_) => _scheduleDebouncedCheckinRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'checkins',
          callback: (_) => _scheduleDebouncedCheckinRefresh(),
        )
        .subscribe();
  }

  /// Realtime check-in yağmurunda layout içi setState döngüsünü önlemek için gecikmeli yenileme.
  void _scheduleDebouncedCheckinRefresh() {
    if (!mounted) return;
    _checkinRealtimeDebounce?.cancel();
    _checkinRealtimeDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) unawaited(_refreshActiveCheckins());
    });
  }

  void _postFrameSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }

  Future<void> _loadShops() async {
    try {
      final shops = await _shopRepository.getShops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
      });
    } catch (_) {
      // Dükkan katmanı opsiyonel olduğu için hatayı sessiz geçiyoruz.
    }
  }

  void _toggleShopsLayer() {
    final next = !_showShops;
    setState(() => _showShops = next);
    if (next) {
      unawaited(_refreshShopsWithUserFeedback());
    }
  }

  Future<void> _refreshShopsWithUserFeedback() async {
    try {
      final shops = await _shopRepository.getShops();
      if (!mounted) return;
      setState(() => _shops = shops);
      if (!mounted || !_showShops) return;
      if (_shops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Haritada gösterilecek dükkan kaydı yok. Kayıtlı dükkan olunca turuncu işaretler görünür.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dükkan listesi yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final spots = await _repository.getSpots(limit: 500);
      setState(() {
        _spotMap
          ..clear()
          ..addEntries(spots.map((s) => MapEntry(s.id, s)));
        _spots = _spotMap.values.toList();
      });
      await _refreshActiveCheckins();
    } catch (e) {
      // Remote hata verirse local cache ile fallback.
      final cached = await _repository.getCachedSpots();
      setState(() {
        _spotMap
          ..clear()
          ..addEntries(cached.map((s) => MapEntry(s.id, s)));
        _spots = _spotMap.values.toList();
        _error = cached.isEmpty ? 'Meralar yüklenemedi.' : null;
      });
      await _refreshActiveCheckins();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectSpot(SpotModel spot) {
    setState(() {
      _sheetSpot = spot;
      _searchResults = const [];
    });

    // Haritayı seçilen meraya ortala.
    try {
      _mapController.move(LatLng(spot.lat, spot.lng), 15);
    } catch (_) {
      // Harita henüz hazır değilse görmezden gel.
    }

    // Sheet bir frame sonra attach oluyor; aynı frame'de animateTo layout assert tetikleyebilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sheetController.isAttached) return;
        _sheetController.animateTo(
          0.32,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });

    unawaited(_loadWeatherForSpot(spot));
    unawaited(_applyDetailedCheckinsForSpot(spot.id));
  }

  /// Açık mera için oy tabanlı gizleme kurallarını uygular (`getCheckinsForSpot`).
  Future<void> _applyDetailedCheckinsForSpot(String spotId) async {
    final epoch = ++_sheetDetailEpoch;
    try {
      final list = await _checkinRepository.getCheckinsForSpot(spotId);
      if (!mounted) return;
      if (epoch != _sheetDetailEpoch) return;
      if (_sheetSpot?.id != spotId) return;
      _postFrameSetState(() {
        final copy = Map<String, List<CheckinModel>>.from(
          _activeCheckinsBySpotId,
        );
        copy[spotId] = list;
        _activeCheckinsBySpotId = copy;
      });
    } catch (_) {
      // Özet liste (getRecentCheckinsAll) kalsın.
    }
  }

  Future<void> _loadWeatherForSpot(SpotModel spot) async {
    _postFrameSetState(() => _weatherLoading = true);
    try {
      final snap = await WeatherService.fetchMeraSheetWeather(
        lat: spot.lat,
        lng: spot.lng,
      );
      if (!mounted) return;
      // Kullanıcı hızlıca başka meraya geçtiyse eski sonucu ezmeyelim.
      if (_sheetSpot?.id != spot.id) return;
      _postFrameSetState(() => _meraWeather = snap);
    } catch (_) {
      // Sessizce geç: kart placeholder kalsın.
    } finally {
      if (mounted) _postFrameSetState(() => _weatherLoading = false);
    }
  }

  Future<void> _goToMyLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final pos = await LocationService.getCurrentPosition(
        purpose: LocationPurpose.mapCenter,
      );
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konumunuz bulunamadı. Lütfen telefonunuzun konum (GPS) özelliğinin açık olduğundan ve uygulamaya konum izni verildiğinden emin olun.',
            ),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      try {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      } catch (e) {
        debugPrint('Harita konuma taşınamadı: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Konum alınırken bir sorun oluştu. Lütfen telefonunuzun konum (GPS) özelliğinin açık olduğundan emin olun ve tekrar deneyin.',
          ),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openDirectionsForSpot(SpotModel spot) async {
    final label = Uri.encodeComponent(spot.name);
    final geo = Uri.parse(
      'geo:${spot.lat},${spot.lng}?q=${spot.lat},${spot.lng}($label)',
    );
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${spot.lat},${spot.lng}',
    );
    try {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint('geo: URL açılamadı: $e');
    }
    try {
      if (await launchUrl(maps, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugPrint('Google Maps URL açılamadı: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harita açılamadı'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _openCheckinForSpot(SpotModel spot) async {
    final result = await context.push<bool>('/checkin/${spot.id}');
    if (!mounted || result != true) return;

    await _refreshActiveCheckins();
    if (!mounted) return;

    if (_sheetSpot?.id == spot.id) {
      await _applyDetailedCheckinsForSpot(spot.id);
    }
    if (!mounted) return;

    if (_sheetSpot?.id == spot.id) {
      await _loadWeatherForSpot(spot);
    }
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sheetSpot?.id != spot.id) return;
      if (!_sheetController.isAttached) return;
      _sheetController.animateTo(
        0.42,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  static const int _searchNearestLimit = 15;
  static const int _searchDropdownMaxRows = 8;

  /// Harita varsayılan merkezi — konum yokken yakınlık sıralaması için.
  static const double _fallbackSearchLat = 41.0082;
  static const double _fallbackSearchLng = 28.9784;

  void _onSearchChanged(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      unawaited(_loadNearestSpotsForSearch());
      return;
    }

    // İsim ve tür üzerinden filtrele
    final qLower = q.toLowerCase();
    final results = <SpotModel>[];
    for (final spot in _spots) {
      final name = spot.name.toLowerCase();
      final type = (spot.type ?? '').toLowerCase();
      if (name.contains(qLower) || type.contains(qLower)) {
        results.add(spot);
        if (results.length >= _searchNearestLimit) break;
      }
    }

    setState(() {
      _searchResults = results;
    });
  }

  /// Boş arama: kullanıcı konumuna en yakın [ _searchNearestLimit ] mera.
  Future<void> _loadNearestSpotsForSearch() async {
    if (!mounted) return;
    if (_spots.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }

    double refLat = _fallbackSearchLat;
    double refLng = _fallbackSearchLng;
    try {
      final now = DateTime.now();
      final cached = _cachedSearchPos;
      final cachedAt = _cachedSearchPosTime;
      final isFresh = cached != null &&
          cachedAt != null &&
          now.difference(cachedAt) < const Duration(seconds: 60);
      final pos = isFresh
          ? cached
          : await LocationService.getCurrentPosition(
              purpose: LocationPurpose.search,
            );
      if (!isFresh && pos != null) {
        _cachedSearchPos = pos;
        _cachedSearchPosTime = now;
      }
      if (pos != null) {
        refLat = pos.latitude;
        refLng = pos.longitude;
      }
    } catch (_) {
      // GPS yok — İstanbul merkezi ile sırala
    }

    if (!mounted) return;

    final sorted = List<SpotModel>.from(_spots);
    sorted.sort((a, b) {
      final da = GeoUtils.distanceInMeters(
        lat1: refLat,
        lng1: refLng,
        lat2: a.lat,
        lng2: a.lng,
      );
      final db = GeoUtils.distanceInMeters(
        lat1: refLat,
        lng1: refLng,
        lat2: b.lat,
        lng2: b.lng,
      );
      return da.compareTo(db);
    });

    setState(() {
      _searchResults = sorted.take(_searchNearestLimit).toList();
    });
  }

  /// Mera pin'i — teardrop ucunun [LatLng] ile çakışması için sabit kutu + piksel anchor.
  /// Zoom'a göre width/height değiştirmek merkez hizasında kayma yaratıyordu.
  static const double _spotMarkerW = 100;
  static const double _spotMarkerH = 130;
  static const double _spotPinSize = 56;
  static const double _spotPinTop = 36;
  static const double _spotPinTipY =
      _spotPinTop + _spotPinSize * 0.92; // spot_marker teardrop ile uyumlu
  static const double _spotPinLeft = (_spotMarkerW - _spotPinSize) / 2;

  /// Cache key: (_spots, _activeCheckinsBySpotId, zoom≥13) üçlüsü.
  /// Her biri yeni instance atandığında referans eşitliği bozulur → cache geçersizleşir.
  Object _markersKey() => (_spots, _activeCheckinsBySpotId, _currentZoom >= 13);

  List<Marker> get _markers {
    final key = _markersKey();
    if (_cachedMarkers != null && _markersCacheKey == key) return _cachedMarkers!;
    _cachedMarkers = _buildMarkers();
    _markersCacheKey = key;
    return _cachedMarkers!;
  }

  List<Marker> _buildMarkers() {
    final tipAlignment = Marker.computePixelAlignment(
      width: _spotMarkerW,
      height: _spotMarkerH,
      left: _spotMarkerW / 2,
      top: _spotPinTipY,
    );
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            width: _spotMarkerW,
            height: _spotMarkerH,
            alignment: tipAlignment,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectSpot(spot),
              child: SizedBox(
                width: _spotMarkerW,
                height: _spotMarkerH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: _spotPinLeft,
                      top: _spotPinTop,
                      child: _buildSpotMarker(spot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _buildShopMarkers() {
    return _shops
        .map(
          (shop) => Marker(
            point: LatLng(shop.lat, shop.lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showShopSheet(shop),
              child: _ShopPin(shop: shop),
            ),
          ),
        )
        .toList();
  }

  void _showShopSheet(ShopModel shop) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShopDetailSheet(shop: shop),
    );
  }

  Widget _buildSpotMarker(SpotModel spot) {
    final checkins = _activeCheckinsBySpotId[spot.id];
    final activeCount = checkins?.where((c) => !c.isStale).length ?? 0;

    // En son check-in'den bu yana geçen süre (dakika) — SpotMarker'ın
    // smooth solma ve renk tonu sistemini besler.
    int? ageMinutes;
    if (checkins != null && checkins.isNotEmpty) {
      // Liste createdAt desc sıralıdır; ilk eleman en yeni check-in.
      ageMinutes = DateTime.now()
          .difference(checkins.first.createdAt)
          .inMinutes;
    }

    return SpotMarker(
      privacyLevel: spot.privacyLevel,
      activeCheckinCount: activeCount,
      checkinAgeMinutes: ageMinutes,
      zoom: _currentZoom,
      spotName: spot.name,
      isLocked: spot.privacyLevel == 'vip' && !_isUstaOrAbove,
    );
  }

  Future<void> _refreshActiveCheckins() async {
    if (!mounted || _spots.isEmpty) return;

    if (_checkinRefreshInFlight) {
      _checkinRefreshQueued = true;
      return;
    }
    _checkinRefreshInFlight = true;
    try {
      while (mounted) {
        _checkinRefreshQueued = false;

        final active = await _checkinRepository.getRecentCheckinsAll();
        final spotIds = _spots.map((s) => s.id).toSet();

        final Map<String, List<CheckinModel>> grouped = {};
        for (final c in active) {
          if (!spotIds.contains(c.spotId)) continue;
          grouped.putIfAbsent(c.spotId, () => []).add(c);
        }

        for (final entry in grouped.entries) {
          entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (!mounted) return;
        _postFrameSetState(() => _activeCheckinsBySpotId = grouped);
        final openId = _sheetSpot?.id;
        if (openId != null) {
          unawaited(_applyDetailedCheckinsForSpot(openId));
        }

        if (!_checkinRefreshQueued) break;
      }
    } catch (_) {
      // UI bozulmasın: kontrol başarısız olursa marker rozetleri değişmez.
    } finally {
      _checkinRefreshInFlight = false;
      if (_checkinRefreshQueued && mounted) {
        _checkinRefreshQueued = false;
        unawaited(_refreshActiveCheckins());
      }
    }
  }

  void _scheduleBoundsSpotsFetch() {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 520), () async {
      if (!mounted) return;
      try {
        final cam = _mapController.camera;
        if (cam.zoom < 10.5) return;
        await _mergeSpotsFromVisibleBounds(cam.visibleBounds);
      } catch (_) {
        // Harita henüz hazır değil
      }
    });
  }

  Future<void> _mergeSpotsFromVisibleBounds(LatLngBounds bounds) async {
    final latSpan = (bounds.north - bounds.south).abs();
    final lngSpan = (bounds.east - bounds.west).abs();
    final padLat = latSpan * 0.12;
    final padLng = lngSpan * 0.12;
    final minLat = bounds.south - padLat;
    final maxLat = bounds.north + padLat;
    final minLng = bounds.west - padLng;
    final maxLng = bounds.east + padLng;
    try {
      final chunk = await _repository.getSpotsInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: 450,
      );
      if (!mounted) return;
      if (chunk.isEmpty) return;
      for (final s in chunk) {
        _spotMap[s.id] = s;
      }
      setState(() => _spots = _spotMap.values.toList());
      await _refreshActiveCheckins();
      final openId = _sheetSpot?.id;
      if (openId != null) {
        unawaited(_applyDetailedCheckinsForSpot(openId));
      }
    } catch (_) {
      // Sessiz — ilk yükleme zaten tam liste veya cache
    }
  }

  @override
  Widget build(BuildContext context) {
    const sheetInitialSize = 0.18;
    const sheetMinSize = 0.14;
    const sheetMaxSize = 0.85;

    final screenHeight = MediaQuery.of(context).size.height;
    final mapFabBottom = _sheetSpot != null
        ? (sheetMinSize * screenHeight) + 72
        : MediaQuery.of(context).padding.bottom + 24;

    final sheetSpot = _sheetSpot;
    final sheetCheckins = sheetSpot == null
        ? const <CheckinModel>[]
        : (_activeCheckinsBySpotId[sheetSpot.id] ?? const <CheckinModel>[]);
    final activeCount = sheetCheckins.where((c) => !c.isStale).length;
    final mostRecent = sheetCheckins.isNotEmpty ? sheetCheckins.first : null;
    final sheetDescriptionTrimmed = sheetSpot?.description?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  0.85, 0,    0,    0, 0,
                  0,    0.85, 0,    0, 0,
                  0,    0,    0.90, 0, 0,
                  0,    0,    0,    1, 0,
                ]),
                child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(41.0082, 28.9784),
                  initialZoom: 11.0,
                  minZoom: 5.0,
                  maxZoom: 19.0,
                  // Varsayılan açık gri; karo boşluklarında “beyaz kare” hissi verir.
                  backgroundColor: AppColors.background,
                  onPositionChanged: (camera, _) {
                    final z = camera.zoom;
                    // Marker boyutları yalnızca zoom 13 eşiğini geçince değişir.
                    // Her küçük zoom değişiminde tüm widget ağacını yeniden
                    // buildlemek yerine sadece eşik aşıldığında setState çağır.
                    final crossedThreshold = (_currentZoom > 13) != (z > 13);
                    _currentZoom = z;
                    if (crossedThreshold && mounted) setState(() {});
                    if (z >= 10.5) _scheduleBoundsSpotsFetch();
                  },
                  onTap: (_, point) {
                    _searchFocusNode.unfocus();
                    setState(() {
                      _searchResults = const [];
                      _sheetSpot = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com'
                        '/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.balikci.app',
                    maxNativeZoom: 19,
                    keepBuffer: 4,
                    panBuffer: 3,
                    tileDisplay: const TileDisplay.instantaneous(),
                    evictErrorTileStrategy: EvictErrorTileStrategy.none,
                    tileProvider: _buildTileProvider(),
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('Tile yükleme hatası: $error');
                    },
                  ),
                  if (_showSpots)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        markers: _markers,
                        maxClusterRadius: 58,
                        size: const Size(42, 42),
                        builder: (context, markers) {
                          return Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Mera kümesinin üstünde çiz — aksi halde işaretler görünmeyebilir.
                  if (_showShops) MarkerLayer(markers: _buildShopMarkers()),
                ],
              ),
              ),
            ),
          ),

          // H9: Kompakt hava kartı — arama çubuğu (48px) altına yerleşir
          // right: 80 → sağdaki katman toggle butonlarıyla çakışmaz
          Positioned(
            top: MediaQuery.of(context).padding.top + 8 + 48 + 8,
            left: 12,
            right: 82,
            child: const WeatherCard(),
          ),

          // Üst: Arama (floating)
          Positioned(
            left: 16,
            right: 78,
            top: MediaQuery.of(context).padding.top + 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mera, tür veya bölge ara...',
                    hintStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                      size: 26,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Temizle',
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              _searchFocusNode.unfocus();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1A2E44),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                  onTap: () => _onSearchChanged(_searchController.text),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: _searchResults.isEmpty
                      ? 0
                      : 56.0 *
                              (_searchResults.length.clamp(1, _searchDropdownMaxRows)) +
                          16,
                  child: _searchResults.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _searchResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Sonuç bulunamadı',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, idx) {
                                    final spot = _searchResults[idx];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        _searchController.text = spot.name;
                                        _searchFocusNode.unfocus();
                                        _selectSpot(spot);
                                        setState(() {
                                          _searchResults = const [];
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              color: AppColors.teal,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    spot.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (spot.type != null)
                                                    const SizedBox(height: 2),
                                                  if (spot.type != null)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white12,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        spot.type!,
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _PrivacyChip(
                                              level: spot.privacyLevel,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),

          // Sağ alt: harita aksiyonları
          Positioned(
            right: 16,
            bottom: mapFabBottom,
            child: _MapActionButton(
              tooltip: 'Konumumu Bul',
              // GPS aranırken butonu devre dışı bırak (spam engeli).
              onPressed: _isLocating ? null : _goToMyLocation,
              icon: _isLocating ? null : Icons.my_location,
              isLoading: _isLocating,
            ),
          ),

          // Sol alt — mera ekle (tema rengi)
          Positioned(
            left: 16,
            bottom: mapFabBottom,
            child: FloatingActionButton.extended(
              heroTag: 'addSpotFab',
              onPressed: () async {
                final ok = await context.push<bool>('/map/add-spot');
                if (!mounted) return;
                if (ok == true) unawaited(_loadSpots());
              },
              backgroundColor: AppColors.mapSpotLayerActive,
              foregroundColor: AppColors.foam,
              elevation: 3,
              extendedPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 0,
              ),
              icon: const Icon(Icons.add_location_alt, size: 20),
              label: const Text(
                'Mera Ekle',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // Top-right: Bildirim + Katman toggles
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final count = ref.watch(unreadCountProvider);
                    final onlineAsync = ref.watch(connectivityProvider);
                    final online = onlineAsync.asData?.value ?? true;

                    Widget buildButton(int count) {
                      return Tooltip(
                        message: 'Bildirimler',
                        child: GestureDetector(
                          onTap: () => context.push(AppRoutes.notifications),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Center(
                                  child: Icon(
                                    Icons.notifications_rounded,
                                    color: count > 0
                                        ? AppColors.sand
                                        : Colors.white,
                                    size: 26,
                                  ),
                                ),
                                // Çevrimiçi/çevrimdışı nokta
                                Positioned(
                                  right: 9,
                                  top: 9,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: online
                                          ? AppColors.success
                                          : AppColors.warning,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                // Okunmamış sayı rozeti
                                if (count > 0)
                                  Positioned(
                                    right: 5,
                                    bottom: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        count > 99 ? '99+' : '$count',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return buildButton(count);
                  },
                ),
                const SizedBox(height: 8),
                _LayerToggleGroup(
                  showSpots: _showSpots,
                  showShops: _showShops,
                  onToggleSpots: () => setState(() => _showSpots = !_showSpots),
                  onToggleShops: _toggleShopsLayer,
                ),
              ],
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Alt: Draggable sheet — yalnızca mera seçilince görünür.
          // Align(bottomCenter) + Stack gevşek kısıtları bazen sheet’e 0 yükseklik verir;
          // hit test: "Cannot hit test a render box with no size". Positioned.fill gerekli.
          if (sheetSpot != null)
            Positioned.fill(
              child: DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: sheetInitialSize,
                minChildSize: sheetMinSize,
                maxChildSize: sheetMaxSize,
                snap: true,
                snapSizes: const [sheetInitialSize, 0.32, 0.42, sheetMaxSize],
                builder: (context, scrollController) {
                  final bottomPad = MediaQuery.of(context).padding.bottom;
                  return Padding(
                    padding: EdgeInsets.only(bottom: bottomPad),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CustomScrollView(
                        key: ValueKey<String>('spot_sheet_${sheetSpot.id}'),
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 12,
                                      ),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.muted.withValues(
                                          alpha: 0.45,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  _SpotSheetHeader(
                                    spot: sheetSpot,
                                    activeCount: activeCount,
                                    hasMuhtar: sheetSpot.muhtarId != null,
                                  ),
                                  const SizedBox(height: 10),
                                  if (sheetSpot.privacyLevel == 'vip' &&
                                      !_isUstaOrAbove)
                                    _VipLockedWidget(
                                      userScore: _currentUserScore,
                                    )
                                  else ...[
                                    if (mostRecent != null)
                                      _LatestCheckinBanner(
                                        checkin: mostRecent,
                                      ),
                                    if (mostRecent != null)
                                      const SizedBox(height: 10),
                                    _MeraWeatherSection(
                                      loading: _weatherLoading,
                                      snap: _meraWeather,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 48,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: _SheetPrimaryButton(
                                              onPressed: () =>
                                                  _openCheckinForSpot(
                                                    sheetSpot,
                                                  ),
                                              icon: Icons.check_circle_outline,
                                              label: 'Balık Var!',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _SheetSecondaryButton(
                                              onPressed: () =>
                                                  _openDirectionsForSpot(
                                                    sheetSpot,
                                                  ),
                                              icon: Icons.directions,
                                              label: 'Yol Tarifi',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (sheetDescriptionTrimmed != null &&
                                        sheetDescriptionTrimmed.isNotEmpty)
                                      Text(
                                        sheetDescriptionTrimmed,
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.foam.withValues(
                                            alpha: 0.78,
                                          ),
                                        ),
                                      ),
                                    if (sheetDescriptionTrimmed != null &&
                                        sheetDescriptionTrimmed.isNotEmpty)
                                      const SizedBox(height: 12),
                                    _RecentCheckinsRow(checkins: sheetCheckins),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_error != null && !_isLoading)
            Positioned(
              left: 16,
              right: 16,
              top: 140,
              child: Material(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Deep-link yükleme banner'ı — bildirimden gelen mera çekilirken gösterilir.
          if (_isDeepLinkLoading)
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).padding.top + 70,
              child: Material(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Mera yükleniyor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// GPS/loading durumunda true — ikon yerine spinner gösterilir.
  final bool isLoading;

  const _MapActionButton({
    required this.tooltip,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        // onPressed null olunca Flutter butonu otomatik disable eder.
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _PrivacyChip extends StatelessWidget {
  final String level;
  const _PrivacyChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      'friends' => ('Arkadaşlar', AppColors.pinFriends),
      'private' => ('Gizli', AppColors.pinPrivate),
      'vip' => ('VIP', AppColors.pinVip),
      _ => ('Herkese Açık', AppColors.pinPublic),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LayerToggleGroup extends StatelessWidget {
  final bool showSpots;
  final bool showShops;
  final VoidCallback onToggleSpots;
  final VoidCallback onToggleShops;

  const _LayerToggleGroup({
    required this.showSpots,
    required this.showShops,
    required this.onToggleSpots,
    required this.onToggleShops,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LayerToggleButton(
          icon: Icons.place_outlined,
          label: 'Meralar',
          active: showSpots,
          onPressed: onToggleSpots,
        ),
        const SizedBox(height: 10),
        _LayerToggleButton(
          icon: Icons.storefront_outlined,
          label: 'Dükkan',
          active: showShops,
          onPressed: onToggleShops,
        ),
      ],
    );
  }
}

class _LayerToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  const _LayerToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppColors.mapSpotLayerActive
        : AppColors.mapSpotLayerInactive;
    final fg = active ? AppColors.foam : AppColors.foam.withValues(alpha: 0.82);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.foam.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotSheetHeader extends ConsumerWidget {
  final SpotModel spot;
  final int activeCount;
  final bool hasMuhtar;

  const _SpotSheetHeader({
    required this.spot,
    required this.activeCount,
    required this.hasMuhtar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavAsync = ref.watch(isFavoritedProvider(spot.id));
    final isFav = isFavAsync.valueOrNull ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spot.name,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.foam,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PrivacyChip(level: spot.privacyLevel),
                  if (hasMuhtar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.sand.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Muhtar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  _ActivePulseCount(count: activeCount),
                ],
              ),
            ],
          ),
        ),
        // Favori butonu
        IconButton(
          tooltip: isFav ? 'Favoriden çıkar' : 'Favorile',
          icon: Icon(
            isFav ? Icons.bookmark : Icons.bookmark_border,
            color: isFav ? AppColors.sand : AppColors.muted,
          ),
          onPressed: () async {
            try {
              await ref
                  .read(favoriteRepositoryProvider)
                  .toggleFavorite(spot.id);
              ref.invalidate(isFavoritedProvider(spot.id));
              ref.invalidate(favoriteSpotsProvider);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Favori güncellenemedi: $e'),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _ActivePulseCount extends StatefulWidget {
  final int count;
  const _ActivePulseCount({required this.count});

  @override
  State<_ActivePulseCount> createState() => _ActivePulseCountState();
}

class _ActivePulseCountState extends State<_ActivePulseCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.count > 0) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _ActivePulseCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0 && !_c.isAnimating) {
      _c.repeat();
    } else if (widget.count <= 0 && _c.isAnimating) {
      _c.stop();
      _c.reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    // ListView / sliver içinde her frame layout boyutu değişmesin: sabit kutu + scale.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final dot = count > 0;
        final pulse = dot ? 1.0 + 0.22 * math.sin(_c.value * math.pi * 2) : 1.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Center(
                child: dot
                    ? Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.45),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count aktif bildirim',
              style: TextStyle(
                color: AppColors.foam.withValues(alpha: 0.88),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MeraWeatherSection extends StatelessWidget {
  final bool loading;
  final MeraWeatherSnapshot? snap;

  const _MeraWeatherSection({
    required this.loading,
    required this.snap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.foam.withValues(alpha: 0.72);
    final s = snap;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s != null)
                Text(
                  _skyEmoji(s),
                  style: const TextStyle(fontSize: 34, height: 1.05),
                )
              else
                Icon(
                  Icons.wb_cloudy_outlined,
                  color: AppColors.primary.withValues(alpha: 0.95),
                  size: 28,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.locationLabel ?? 'Hava durumu',
                      style: TextStyle(
                        color: AppColors.foam.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.locationSubtitle,
                        style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 10),
            Text(
              _skyText(s),
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.95),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🌡️ ${_tempC(s).round()}°C   ·   💨 ${_windKmh(s).round()} km/h',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foam,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ] else if (!loading) ...[
            const SizedBox(height: 10),
            Text(
              'Hava verisi alınamadı.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  double _tempC(MeraWeatherSnapshot s) {
    final h = s.currentHour;
    if (h != null) return h.temperature;
    return s.weather.tempCelsius;
  }

  double _windKmh(MeraWeatherSnapshot s) {
    final h = s.currentHour;
    if (h != null) return h.windspeed;
    return s.weather.windKmh;
  }

  String _skyText(MeraWeatherSnapshot s) {
    final h = s.currentHour;
    if (h != null) return MeraWeatherDisplay.skyCondition(h);
    return MeraWeatherDisplay.skyConditionFromWmo(
      weatherCode: s.weather.weatherCode ?? 0,
      precipitationMm: s.weather.precipitation ?? 0,
    );
  }

  String _skyEmoji(MeraWeatherSnapshot s) {
    final h = s.currentHour;
    if (h != null) return h.weatherEmoji;
    final code = s.weather.weatherCode ?? 0;
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 49) return '🌫️';
    if (code <= 69) return '🌧️';
    if (code <= 79) return '❄️';
    if (code <= 99) return '⛈️';
    return '🌡️';
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _SheetPrimaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SheetSecondaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _SheetSecondaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.foam.withValues(alpha: 0.92);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: fg),
      label: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Son bildirimleri dikey kart listesi olarak gösterir (oylama yalnızca konum pop-up).
class _RecentCheckinsRow extends StatelessWidget {
  final List<CheckinModel> checkins;

  const _RecentCheckinsRow({required this.checkins});

  @override
  Widget build(BuildContext context) {
    if (checkins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.muted, size: 18),
            const SizedBox(width: 10),
            Text(
              'Henüz bildirim yok. İlk bildiren sen ol!',
              style: AppTextStyles.body.copyWith(
                color: AppColors.foam.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Bildirimler',
          style: AppTextStyles.h3.copyWith(color: AppColors.foam, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ...checkins
            .take(5)
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CheckinCard(checkin: c),
              ),
            ),
      ],
    );
  }
}

/// Tek check-in kartı — zaman, balık, kalabalık özeti (oylama yalnızca konum pop-up).
class _CheckinCard extends StatelessWidget {
  final CheckinModel checkin;

  const _CheckinCard({required this.checkin});

  String _fishLabel(String? d) => switch (d) {
    'yoğun' => '🐟🐟🐟 Çok Balık',
    'normal' => '🐟🐟 Normal',
    'az' => '🐟 Az Balık',
    'yok' => '❌ Balık Yok',
    _ => '🐟 ?',
  };

  String _crowdLabel(String? c) => switch (c) {
    'yoğun' => '👥👥 Kalabalık',
    'normal' => '👥 Normal',
    'az' => '👤 Sakin',
    'boş' => '🏖️ Boş',
    _ => '👥 ?',
  };

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final active = !checkin.isStale;
    final total = checkin.trueVotes + checkin.falseVotes;
    final trustPct = total == 0
        ? 0.0
        : (checkin.trueVotes / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.teal.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.teal.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol: zaman + aktif nokta
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatAgo(checkin.createdAt),
                style: TextStyle(
                  color: AppColors.foam.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Orta: balık + kalabalık
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fishLabel(checkin.fishDensity),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.foam,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (checkin.fishSpecies.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    checkin.fishSpecies.join(' · '),
                    style: TextStyle(
                      color: AppColors.sand.withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _crowdLabel(checkin.crowdLevel),
                  style: TextStyle(
                    color: AppColors.foam.withValues(alpha: 0.70),
                    fontSize: 13,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 12,
                        color: AppColors.success.withValues(alpha: 0.80),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '%${(trustPct * 100).round()} güven ($total oy)',
                        style: TextStyle(
                          color: AppColors.foam.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En son check-in'i göze çarpan bir banner olarak gösterir.
class _LatestCheckinBanner extends StatelessWidget {
  final CheckinModel checkin;
  const _LatestCheckinBanner({required this.checkin});

  String _fishLabel(String? d) => switch (d) {
    'yoğun' => '🐟🐟🐟 Çok Balık',
    'normal' => '🐟🐟 Normal Balık',
    'az' => '🐟 Az Balık',
    'yok' => '❌ Balık Yok',
    _ => '🐟 Bildirim Var',
  };

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${dt.day}.${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isStale = checkin.isStale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isStale
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStale
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStale ? Icons.history : Icons.circle,
            size: 10,
            color: isStale ? AppColors.muted : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fishLabel(checkin.fishDensity),
                  style: TextStyle(
                    color: isStale ? AppColors.muted : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (checkin.fishSpecies.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    checkin.fishSpecies.join(' · '),
                    style: TextStyle(
                      color: isStale
                          ? AppColors.muted.withValues(alpha: 0.8)
                          : AppColors.sand.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatAgo(checkin.createdAt),
            style: TextStyle(
              color: AppColors.foam.withValues(alpha: 0.60),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isStale) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ESKİ',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dükkan Pin — harita üzerinde belirgin turuncu ikon
// ──────────────────────────────────────────────────────────────────────────────

class _ShopPin extends StatelessWidget {
  final ShopModel shop;
  const _ShopPin({required this.shop});

  static const _typeIcons = <String, IconData>{
    'balikci_dukkani': Icons.set_meal,
    'olta_malzemesi': Icons.sports_sharp,
    'tekne_kiralama': Icons.directions_boat,
    'balikci_barina': Icons.anchor,
    'nalbur': Icons.hardware,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[shop.type] ?? Icons.storefront;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.shopMarker,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.foam, size: 22),
          if (shop.verified)
            const Icon(Icons.verified, color: AppColors.foam, size: 10),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dükkan Detay Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _ShopDetailSheet extends StatelessWidget {
  final ShopModel shop;
  const _ShopDetailSheet({required this.shop});

  static const _typeLabels = <String, String>{
    'balikci_dukkani': 'Balıkçı Dükkanı',
    'olta_malzemesi': 'Olta & Takım',
    'tekne_kiralama': 'Tekne Kiralama',
    'balikci_barina': 'Balıkçı Barınağı',
    'nalbur': 'Nalbur',
  };

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabels[shop.type] ?? shop.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Başlık + tür etiketi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.shopMarker.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: AppColors.shopMarker,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: AppTextStyles.h3.copyWith(color: AppColors.foam),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        if (shop.verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            color: AppColors.secondary.withValues(alpha: 0.95),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Doğrulandı',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.secondary.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Telefon
          if (shop.phone != null)
            _InfoRow(icon: Icons.phone_outlined, text: shop.phone!),

          // Çalışma saatleri
          if (shop.hours != null)
            _InfoRow(icon: Icons.schedule_outlined, text: shop.hours!),

          if (shop.phone == null && shop.hours == null)
            Text(
              'İletişim bilgisi henüz eklenmedi.',
              style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _VipLockedWidget extends StatelessWidget {
  final int userScore;
  const _VipLockedWidget({required this.userScore});

  @override
  Widget build(BuildContext context) {
    const ustaThreshold = 2000;
    final remaining = (ustaThreshold - userScore).clamp(0, ustaThreshold);
    final progress = (userScore / ustaThreshold).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: AppColors.accent),
          const SizedBox(height: 12),
          const Text(
            'Bu Gizli Mera Kilitli 🔒',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Usta Balıkçı olmana $remaining puan kaldı.\nMera paylaşarak veya balık bildirimi yaparak puan kazanabilirsin.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir mera paylaşırsan +50 puan kazanırsın! 🎣',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.foam),
          ),
        ],
      ),
    );
  }
}
