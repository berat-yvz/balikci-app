import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/data/models/shop_model.dart';
import 'package:balikci_app/features/map/widgets/spot_marker.dart';
import 'package:balikci_app/features/map/widgets/vote_dialog.dart';
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
  static const double _kSheetMaxSize = 0.85;

  final SpotRepository _repository = SpotRepository();
  final CheckinRepository _checkinRepository = CheckinRepository();
  final ShopRepository _shopRepository = ShopRepository();
  final MapController _mapController = MapController();

  List<SpotModel> _spots = const [];
  List<ShopModel> _shops = const [];
  Map<String, List<CheckinModel>> _activeCheckinsBySpotId = const {};
  bool _isLoading = true;
  String? _error;

  bool _showShops = false;
  bool _showSpots = true;

  bool _checkingCheckins = false;
  Timer? _checkinPollTimer;
  RealtimeChannel? _checkinsRealtimeChannel;

  SpotModel? _sheetSpot;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SpotModel> _searchResults = const [];

  WeatherModel? _spotWeather;
  bool _weatherLoading = false;

  double _currentZoom = 10;

  /// Geçerli kullanıcının rütbesi — VIP pin kilidi için kullanılır.
  /// 'acemi' | 'olta_kurdu' | 'usta' | 'deniz_reisi'
  String _currentUserRank = 'acemi';

  bool get _isUstaOrAbove =>
      _currentUserRank == 'usta' || _currentUserRank == 'deniz_reisi';

  @override
  void initState() {
    super.initState();
    _initializeCacheAndLoad();
    _fetchCurrentUserRank();
  }

  @override
  void dispose() {
    unawaited(_checkinsRealtimeChannel?.unsubscribe());
    _checkinsRealtimeChannel = null;
    _checkinPollTimer?.cancel();
    _sheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeCacheAndLoad() async {
    await _loadSpots();
    await _loadShops();
    _startCheckinsRealtime();
    _openInitialSpotIfNeeded();
  }

  Future<void> _fetchCurrentUserRank() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile = await UserRepository().getProfile(uid);
      if (mounted && profile != null) {
        setState(() => _currentUserRank = profile.rank);
      }
    } catch (_) {
      // Rütbe alınamazsa 'acemi' varsayılanı kalır — VIP pinler kilitli görünür.
    }
  }

  /// Bildirimden gelen initialSpotId varsa ilk frame'den sonra o mera seçilir.
  void _openInitialSpotIfNeeded() {
    final targetId = widget.initialSpotId;
    if (targetId == null || _spots.isEmpty) return;
    try {
      final spot = _spots.firstWhere((s) => s.id == targetId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectSpot(spot);
      });
    } catch (_) {
      // Mera bulunamadıysa sessizce devam et
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
          callback: (_) {
            if (mounted) unawaited(_refreshActiveCheckins());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'checkins',
          callback: (_) {
            if (mounted) unawaited(_refreshActiveCheckins());
          },
        )
        .subscribe();
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

  Future<void> _loadSpots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final spots = await _repository.getSpots(limit: 500);
      setState(() {
        _spots = spots;
      });
      await _refreshActiveCheckins();
    } catch (e) {
      // Remote hata verirse local cache ile fallback.
      final cached = await _repository.getCachedSpots();
      setState(() {
        _spots = cached;
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
    // VIP mera: Usta veya üzeri rütbe gerektirir.
    if (spot.privacyLevel == 'vip' && !_isUstaOrAbove) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 Bu VIP mera Usta rütbesi ve üzeri için erişilebilir.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

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

    // DraggableScrollableSheet'i aç (spot seçilince).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sheetController.isAttached) return;
      _sheetController.animateTo(
        0.32,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    unawaited(_loadWeatherForSpot(spot));
  }

  Future<void> _loadWeatherForSpot(SpotModel spot) async {
    setState(() => _weatherLoading = true);
    try {
      final w = await WeatherService.getWeatherForLocation(
        lat: spot.lat,
        lng: spot.lng,
      );
      if (!mounted) return;
      // Kullanıcı hızlıca başka meraya geçtiyse eski sonucu ezmeyelim.
      if (_sheetSpot?.id != spot.id) return;
      setState(() => _spotWeather = w);
    } catch (_) {
      // Sessizce geç: kart placeholder kalsın.
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  Future<void> _goToMyLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum alınamadı. İzin veya GPS açık mı kontrol edin.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    try {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (e) {
      debugPrint('Harita konuma taşınamadı: $e');
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
    if (!mounted) return;
    if (result == true) {
      await _refreshActiveCheckins();
      if (_sheetSpot?.id == spot.id) {
        await _loadWeatherForSpot(spot);
      }
      if (!mounted) return;
      setState(() {});
      // Check-in sonrası içerik taşmasından kaynaklanan kaydırma önceliğini
      // ortadan kaldırmak için sheet'i tam boyuta aç.  Böylece grab handle,
      // favori butonu ve diğer aksiyonlar ekran dışına çıkmaz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sheetController.isAttached) return;
        if (_sheetSpot?.id == spot.id) {
          _sheetController.animateTo(
            _kSheetMaxSize,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _openEditForSpot(SpotModel spot) {
    context.push(AppRoutes.mapEditSpot, extra: spot);
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      // Arama boşken tüm meraları göster (max 8)
      setState(() {
        _searchResults = _spots.take(8).toList();
      });
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
        if (results.length >= 8) break;
      }
    }

    setState(() {
      _searchResults = results;
    });
  }

  List<Marker> _buildMarkers() {
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            // Zoom > 13'te isim etiketi için ekstra yükseklik
            width: _currentZoom > 13 ? 72 : 52,
            height: _currentZoom > 13 ? 80 : 52,
            child: GestureDetector(
              onTap: () => _selectSpot(spot),
              child: _buildSpotMarker(spot),
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
    if (_checkingCheckins) return;
    if (!mounted) return;
    if (_spots.isEmpty) return;

    _checkingCheckins = true;
    try {
      final active = await _checkinRepository.getRecentCheckinsAll();
      final spotIds = _spots.map((s) => s.id).toSet();

      final Map<String, List<CheckinModel>> grouped = {};
      for (final c in active) {
        if (!spotIds.contains(c.spotId)) continue;
        grouped.putIfAbsent(c.spotId, () => []).add(c);
      }

      // Created_at desc olduğu için çoğu zaman zaten doğru sıralı; yine de güvenli olsun.
      for (final entry in grouped.entries) {
        entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      if (!mounted) return;
      setState(() => _activeCheckinsBySpotId = grouped);
    } catch (_) {
      // UI bozulmasın: kontrol başarısız olursa marker rozetleri değişmez.
    } finally {
      _checkingCheckins = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const sheetInitialSize = 0.18;
    const sheetMinSize = 0.14;
    const sheetMaxSize = 0.85;

    final screenHeight = MediaQuery.of(context).size.height;
    final mapFabBottom = (sheetMinSize * screenHeight) + 72;

    final sheetSpot = _sheetSpot;
    final sheetCheckins = sheetSpot == null
        ? const <CheckinModel>[]
        : (_activeCheckinsBySpotId[sheetSpot.id] ?? const <CheckinModel>[]);
    final activeCount = sheetCheckins.where((c) => !c.isStale).length;
    final mostRecent = sheetCheckins.isNotEmpty ? sheetCheckins.first : null;

    final uid = SupabaseService.auth.currentUser?.id;
    final isOwner = sheetSpot != null && uid != null && uid == sheetSpot.userId;

    final weather = _spotWeather;
    final windKmh = weather != null ? weather.windKmh.round().toString() : '—';
    final tempC = weather != null
        ? weather.tempCelsius.round().toString()
        : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(41.0082, 28.9784),
                initialZoom: 11.0,
                minZoom: 5.0,
                maxZoom: 19.0,
                onPositionChanged: (pos, _) {
                  final z = pos.zoom;
                  // Marker boyutları yalnızca zoom 13 eşiğini geçince değişir.
                  // Her küçük zoom değişiminde tüm widget ağacını yeniden
                  // buildlemek yerine sadece eşik aşıldığında setState çağır.
                  final crossedThreshold = (_currentZoom > 13) != (z > 13);
                  _currentZoom = z;
                  if (crossedThreshold && mounted) setState(() {});
                },
                onTap: (_, point) {
                  if (_searchResults.isNotEmpty) {
                    _searchFocusNode.unfocus();
                    setState(() => _searchResults = const []);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  maxZoom: 19,
                  maxNativeZoom: 19,
                  tileSize: 256,
                  // keepBuffer: görüntü alanının dışında bellekte tutulan
                  // tile satır/sütun sayısı. Yüksek değer zoom/pan
                  // sırasında boşlukları/bozulmaları önler.
                  keepBuffer: 4,
                  panBuffer: 2,
                  evictErrorTileStrategy:
                      EvictErrorTileStrategy.notVisibleRespectMargin,
                  userAgentPackageName: 'com.balikci.app',
                ),
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  maxZoom: 19,
                  maxNativeZoom: 19,
                  tileSize: 256,
                  keepBuffer: 4,
                  panBuffer: 2,
                  evictErrorTileStrategy:
                      EvictErrorTileStrategy.notVisibleRespectMargin,
                  userAgentPackageName: 'com.balikci.app',
                ),
                if (_showShops) MarkerLayer(markers: _buildShopMarkers()),
                if (_showSpots)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: _buildMarkers(),
                      maxClusterRadius: 58,
                      size: const Size(42, 42),
                      builder: (context, markers) {
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F6E56),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
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
              ],
            ),
          ),

          // H9: Kompakt hava kartı — arama çubuğu (48px) altına yerleşir
          // right: 80 → sağdaki katman toggle butonlarıyla çakışmaz
          Positioned(
            top: MediaQuery.of(context).padding.top + 8 + 48 + 8,
            left: 12,
            right: 80,
            child: const WeatherCard(),
          ),

          // Üst: Arama (floating)
          Positioned(
            left: 16,
            right: 72,
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
                      : 56.0 * (_searchResults.length.clamp(1, 6)) + 16,
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
                                  itemCount: _searchResults.length.clamp(0, 6),
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
            child: Column(
              children: [
                _MapActionButton(
                  icon: Icons.my_location,
                  tooltip: 'Konumum',
                  onPressed: _goToMyLocation,
                ),
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.add_location_alt_outlined,
                  tooltip: 'Mera ekle',
                  onPressed: () async {
                    final ok = await context.push<bool>('/map/add-spot');
                    if (!mounted) return;
                    if (ok == true) unawaited(_loadSpots());
                  },
                ),
              ],
            ),
          ),

          // ADIM 8: Sol alt "+ Nokta Ekle" FAB
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
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_location_alt, size: 22),
              label: const Text(
                '+ Nokta Ekle',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
                    final unreadAsync = ref.watch(unreadCountProvider);
                    final onlineAsync = ref.watch(connectivityProvider);
                    final online = onlineAsync.asData?.value ?? true;

                    Widget badgeFor(int count) {
                      final showBadge = count > 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            online
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            color: online
                                ? AppColors.foam.withValues(alpha: 0.75)
                                : AppColors.warning.withValues(alpha: 0.85),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: online
                                    ? AppColors.success
                                    : AppColors.warning,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.navy,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          if (showBadge)
                            Positioned(
                              right: -8,
                              bottom: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.sand,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }

                    return unreadAsync.when(
                      data: (count) => IconButton(
                        tooltip: 'Bildirimler',
                        onPressed: () => context.push(AppRoutes.notifications),
                        icon: badgeFor(count),
                      ),
                      loading: () => IconButton(
                        tooltip: 'Bildirimler',
                        onPressed: () => context.push(AppRoutes.notifications),
                        icon: badgeFor(0),
                      ),
                      error: (_, _) => IconButton(
                        tooltip: 'Bildirimler',
                        onPressed: () => context.push(AppRoutes.notifications),
                        icon: badgeFor(0),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _LayerToggleGroup(
                  showSpots: _showSpots,
                  showShops: _showShops,
                  onToggleSpots: () => setState(() => _showSpots = !_showSpots),
                  onToggleShops: () => setState(() => _showShops = !_showShops),
                ),
              ],
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Alt: Draggable sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: sheetInitialSize,
              minChildSize: sheetMinSize,
              maxChildSize: sheetMaxSize,
              snap: true,
              snapSizes: const [sheetInitialSize, 0.32, sheetMaxSize],
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
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (sheetSpot == null)
                          Text(
                            'Mera Seç',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.foam,
                            ),
                          )
                        else
                          _SpotSheetHeader(
                            spot: sheetSpot,
                            activeCount: activeCount,
                            hasMuhtar: sheetSpot.muhtarId != null,
                          ),
                        const SizedBox(height: 10),
                        if (sheetSpot != null) ...[
                          // Son durum özeti (en yeni bildirim varsa)
                          if (mostRecent != null)
                            _LatestCheckinBanner(checkin: mostRecent),
                          if (mostRecent != null) const SizedBox(height: 10),

                          _WeatherMiniRow(
                            loading: _weatherLoading,
                            tempC: tempC,
                            windKmh: windKmh,
                            waveM: weather?.waveHeight,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _SheetPrimaryButton(
                                  onPressed: () =>
                                      _openCheckinForSpot(sheetSpot),
                                  icon: Icons.check_circle_outline,
                                  label: 'Balık Var!',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SheetSecondaryButton(
                                  onPressed: () =>
                                      _openDirectionsForSpot(sheetSpot),
                                  icon: Icons.directions,
                                  label: 'Yol Tarifi',
                                ),
                              ),
                            ],
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 10),
                            _SheetSecondaryButton(
                              onPressed: () => _openEditForSpot(sheetSpot),
                              icon: Icons.edit_outlined,
                              label: 'Mera Düzenle',
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (sheetSpot.description?.trim().isNotEmpty == true)
                            Text(
                              sheetSpot.description!,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.foam.withValues(alpha: 0.78),
                              ),
                            ),
                          if (sheetSpot.description?.trim().isNotEmpty == true)
                            const SizedBox(height: 12),
                          _RecentCheckinsRow(checkins: sheetCheckins),
                        ] else ...[
                          Text(
                            'Haritada bir meraya dokun — anlık balık durumu, hava ve yol tarifi burada görünür.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.foam.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _EmptySheetHints(),
                        ],
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
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
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
        ? AppColors.teal.withValues(alpha: 0.85)
        : AppColors.navy.withValues(alpha: 0.70);
    final fg = active ? AppColors.foam : AppColors.foam.withValues(alpha: 0.82);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.foam.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
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
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value;
        final dot = count > 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot)
              Container(
                width: 8 + 2 * t,
                height: 8 + 2 * t,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.45),
                      blurRadius: 10 * (0.4 + t),
                      spreadRadius: 1.0 + 2.0 * t,
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
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

class _WeatherMiniRow extends StatelessWidget {
  final bool loading;
  final String tempC;
  final String windKmh;
  final double? waveM;

  const _WeatherMiniRow({
    required this.loading,
    required this.tempC,
    required this.windKmh,
    required this.waveM,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(label: '🌡️ sıcaklık', value: '$tempC°C'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(label: '💨 rüzgar', value: '$windKmh km/h'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              label: '🌊 dalga',
              value: waveM == null ? '—' : '${waveM!.toStringAsFixed(1)} m',
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.foam.withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.foam,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
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
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
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
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.foam.withValues(alpha: 0.92)),
        label: Text(
          label,
          style: TextStyle(color: AppColors.foam.withValues(alpha: 0.92)),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Son bildirimleri dikey kart listesi olarak gösterir.
/// Her kart; zaman, balık yoğunluğu, kalabalık ve "Doğru mu?" butonunu içerir.
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
                child: _CheckinCard(
                  checkin: c,
                  onVoteTap: () => VoteDialog.show(context, checkin: c),
                ),
              ),
            ),
      ],
    );
  }
}

/// Tek check-in kartı — zaman, balık, kalabalık + "Doğru mu?" butonu.
class _CheckinCard extends StatelessWidget {
  final CheckinModel checkin;
  final VoidCallback onVoteTap;

  const _CheckinCard({required this.checkin, required this.onVoteTap});

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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          const SizedBox(width: 8),

          // Sağ: "Doğru mu?" butonu
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: onVoteTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppColors.foam,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Doğru\nmu?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
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
            child: Text(
              _fishLabel(checkin.fishDensity),
              style: TextStyle(
                color: isStale ? AppColors.muted : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
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

class _EmptySheetHints extends StatelessWidget {
  const _EmptySheetHints();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app_outlined, color: Color(0xFFB8C7DA), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pin\'e dokununca: balık durumu, kalabalık, hava ve "Balık Var!" butonu çıkar.',
              style: TextStyle(
                color: Color(0xFFB8C7DA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
        color: const Color(0xFFF57C00), // turuncu — meralardan farklı
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
          Icon(icon, color: Colors.white, size: 20),
          if (shop.verified)
            const Icon(Icons.verified, color: Colors.white, size: 10),
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
                  color: const Color(0xFFF57C00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, color: Color(0xFFF57C00), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: AppTextStyles.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                        ),
                        if (shop.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Color(0xFF4CB2FF), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            'Doğrulandı',
                            style: AppTextStyles.caption.copyWith(color: const Color(0xFF4CB2FF)),
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
            _InfoRow(
              icon: Icons.phone_outlined,
              text: shop.phone!,
            ),

          // Çalışma saatleri
          if (shop.hours != null)
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: shop.hours!,
            ),

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
          Text(text, style: AppTextStyles.body.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
