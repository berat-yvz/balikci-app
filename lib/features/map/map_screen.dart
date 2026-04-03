import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'package:balikci_app/features/map/widgets/weather_card.dart';
import 'package:balikci_app/data/repositories/shop_repository.dart';
import 'package:balikci_app/shared/providers/connectivity_provider.dart';
import 'package:balikci_app/shared/providers/notification_provider.dart';

/// Harita ekranı — H3 temel implementasyon.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static final LatLng _initialCenter = LatLng(41.015, 28.979); // Istanbul

  final SpotRepository _repository = SpotRepository();
  final CheckinRepository _checkinRepository = CheckinRepository();
  final ShopRepository _shopRepository = ShopRepository();
  final MapController _mapController = MapController();

  /// FMTC basarisiz olursa ag uzerinden [NetworkTileProvider] (karo gorunur kalir).
  TileProvider _tileProvider = NetworkTileProvider();

  List<SpotModel> _spots = const [];
  List<ShopModel> _shops = const [];
  Map<String, List<CheckinModel>> _activeCheckinsBySpotId = const {};
  bool _isLoading = true;
  String? _error;

  bool _showShops = false;
  bool _showSpots = true;
  bool _showWeatherOverlay = false;

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

  SpotModel? _nearbySpotForFab;
  bool _checkingNearby = false;
  Timer? _nearbyTimer;

  @override
  void initState() {
    super.initState();
    _initializeCacheAndLoad();
  }

  @override
  void dispose() {
    unawaited(_checkinsRealtimeChannel?.unsubscribe());
    _checkinsRealtimeChannel = null;
    _checkinPollTimer?.cancel();
    _nearbyTimer?.cancel();
    _sheetController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeCacheAndLoad() async {
    try {
      await FMTCObjectBoxBackend().initialise();
      if (mounted) {
        setState(
          () => _tileProvider = FMTCStore('balikci_map_h3').getTileProvider(),
        );
      }
    } catch (_) {
      // Cache yoksa _tileProvider NetworkTileProvider olarak kalir.
    }
    await _loadSpots();
    await _loadShops();
    // H5: Realtime ile check-in değişikliklerini yakalayacağız.
    // Polling sadece "solukluk/yaşlandırma" için (created_at tabanlı) çalışsın diye tutuluyor.
    _checkinPollTimer?.cancel();
    _checkinPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      setState(() {});
    });

    _startCheckinsRealtime();

    // Nearby spot detection for "Check-in Yap" FAB.
    _nearbyTimer?.cancel();
    _nearbyTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      unawaited(_updateNearbySpotForFab());
    });
    unawaited(_updateNearbySpotForFab());
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

  void _startCheckinsRealtime() {
    if (_checkinsRealtimeChannel != null) return;

    try {
      // Basit yaklaşım: checkins değişince global aktif check-in'i tekrar çekiyoruz.
      // (Realtime event yoğunluğunda DB load'u artırmamak için _refreshActiveCheckins içi guard var.)
      _checkinsRealtimeChannel = SupabaseService.client.channel(
        'realtime:public:checkins',
      );

      _checkinsRealtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'checkins',
            callback: (payload) {
              // Insert/Update/Delete geldiğinde aktif checkin listesini güncelle.
              unawaited(_refreshActiveCheckins());
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime başarısız olursa polling ile yaşamaya devam ederiz.
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
        _error = cached.isEmpty ? 'Meralar yuklenemedi.' : null;
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
          content: Text('Konum alinamadi. Izin veya GPS acik mi kontrol edin.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    try {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {}
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
    } catch (_) {}
    try {
      if (await launchUrl(maps, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harita acilamadi'),
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
      setState(() {});
    }
  }

  void _openEditForSpot(SpotModel spot) {
    context.push('/map/edit-spot', extra: spot);
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = const [];
      });
      return;
    }

    // Hızlı arama: ilk birkaç sonucu alıp erken kesiyoruz.
    final qLower = q.toLowerCase();
    final results = <SpotModel>[];
    for (final spot in _spots) {
      final name = spot.name;
      if (name.toLowerCase().contains(qLower)) {
        results.add(spot);
        if (results.length >= 8) break;
      }
    }

    setState(() {
      _searchResults = results;
    });
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const r = 6371000.0; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLng = (lng2 - lng1) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _updateNearbySpotForFab() async {
    if (_checkingNearby) return;
    if (!mounted) return;
    if (_spots.isEmpty) return;
    _checkingNearby = true;
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        setState(() => _nearbySpotForFab = null);
        return;
      }

      SpotModel? best;
      double bestDist = double.infinity;
      for (final s in _spots) {
        final d = _distanceMeters(
          lat1: s.lat,
          lng1: s.lng,
          lat2: pos.latitude,
          lng2: pos.longitude,
        );
        if (d < bestDist) {
          bestDist = d;
          best = s;
        }
      }

      // Visible if within 500m.
      setState(() {
        if (best != null && bestDist <= 500) {
          _nearbySpotForFab = best;
        } else {
          _nearbySpotForFab = null;
        }
      });
    } catch (_) {
      // Silently ignore.
    } finally {
      _checkingNearby = false;
    }
  }

  List<Marker> _buildMarkers() {
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            width: _currentZoom > 13 ? 56 : 48,
            height: _currentZoom > 13 ? 56 : 48,
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
            width: 44,
            height: 44,
            child: Icon(Icons.storefront, color: Colors.orange, size: 32),
          ),
        )
        .toList();
  }

  Widget _buildSpotMarker(SpotModel spot) {
    final checkins = _activeCheckinsBySpotId[spot.id];
    final activeCount = checkins?.where((c) => !c.isStale).length ?? 0;
    final hasStale = checkins?.any((c) => c.isStale) ?? false;

    return SpotMarker(
      privacyLevel: spot.privacyLevel,
      activeCheckinCount: activeCount,
      hasStaleCheckins: hasStale,
      zoom: _currentZoom,
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
    final navBottom = MediaQuery.of(context).padding.bottom;
    final mapFabBottom = (sheetMinSize * screenHeight) + 72;
    final checkinFabBottom = (sheetMinSize * screenHeight) + navBottom + 16;

    final sheetSpot = _sheetSpot;
    final sheetCheckins = sheetSpot == null
        ? const <CheckinModel>[]
        : (_activeCheckinsBySpotId[sheetSpot.id] ?? const <CheckinModel>[]);
    final activeCount = sheetCheckins.where((c) => !c.isStale).length;
    final mostRecent = sheetCheckins.isNotEmpty ? sheetCheckins.first : null;

    final fishDensityLabel = mostRecent?.fishDensity ?? 'yoğun';
    final fishDensityTitle = switch (fishDensityLabel) {
      'yoğun' => 'Balık Yoğun',
      'normal' => 'Balık Normal',
      'az' => 'Balık Az',
      'yok' => 'Balık Yok',
      _ => 'Balık Yoğun',
    };

    final uid = SupabaseService.auth.currentUser?.id;
    final isOwner = sheetSpot != null && uid != null && uid == sheetSpot.userId;

    final weather = _spotWeather;
    final windKmh = weather != null ? weather.windKmh.round().toString() : '—';
    final tempC = weather != null
        ? weather.tempCelsius.round().toString()
        : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _nearbySpotForFab == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: checkinFabBottom),
              child: SizedBox(
                height: 52,
                child: FloatingActionButton.extended(
                  onPressed: () => _openCheckinForSpot(_nearbySpotForFab!),
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.foam,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Check-in Yap'),
                ),
              ),
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 10,
                onPositionChanged: (pos, _) {
                  final z = pos.zoom;
                  if ((z - _currentZoom).abs() >= 0.01 && mounted) {
                    setState(() => _currentZoom = z);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.balikciapp.balikci_app',
                  tileProvider: _tileProvider,
                ),
                if (_showWeatherOverlay) ColoredBox(color: Colors.transparent),
                if (_showShops) MarkerLayer(markers: _buildShopMarkers()),
                if (_showSpots)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: _buildMarkers(),
                      maxClusterRadius: 58,
                      size: const Size(42, 42),
                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.foam.withValues(alpha: 0.85),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 8 + 48 + 8,
            left: 0,
            right: 0,
            child: const WeatherCard(),
          ),

          // Üst: Arama (floating) + sync + bildirimler
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: _searchFocusNode.hasFocus
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Colors.white60,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: _searchController.text.isEmpty
                                          ? 'Mera ara...'
                                          : null,
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      _onSearchChanged(value);
                                      setState(() {});
                                    },
                                    onTap: () => setState(() {}),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
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
                                  ),
                              ],
                            ),
                          ),
                        ),
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
                                margin: const EdgeInsets.only(
                                  top: 4,
                                  right: 64,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _searchResults.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Sonuç bulunamadı',
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                        itemCount: _searchResults.length.clamp(
                                          0,
                                          6,
                                        ),
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 4),
                                        itemBuilder: (context, idx) {
                                          final spot = _searchResults[idx];
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () {
                                              _searchController.text =
                                                  spot.name;
                                              _searchFocusNode.unfocus();
                                              _selectSpot(spot);
                                              setState(() {
                                                _searchResults = const [];
                                              });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          spot.name,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (spot.type != null)
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                        if (spot.type != null)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 3,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .white12,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        999,
                                                                      ),
                                                                ),
                                                            child: Text(
                                                              spot.type!,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        11,
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

                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: unreadAsync.when(
                        data: (count) => IconButton(
                          tooltip: 'Bildirimler',
                          onPressed: () => context.push('/notifications'),
                          icon: badgeFor(count),
                        ),
                        loading: () => IconButton(
                          tooltip: 'Bildirimler',
                          onPressed: () => context.push('/notifications'),
                          icon: badgeFor(0),
                        ),
                        error: (_, _) => IconButton(
                          tooltip: 'Bildirimler',
                          onPressed: () => context.push('/notifications'),
                          icon: badgeFor(0),
                        ),
                      ),
                    );
                  },
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

          // Top-right: Katman toggles (spots / shops / weather)
          Positioned(
            right: 12,
            top: 66,
            child: _LayerToggleGroup(
              showSpots: _showSpots,
              showShops: _showShops,
              showWeather: _showWeatherOverlay,
              onToggleSpots: () => setState(() => _showSpots = !_showSpots),
              onToggleShops: () => setState(() => _showShops = !_showShops),
              onToggleWeather: () =>
                  setState(() => _showWeatherOverlay = !_showWeatherOverlay),
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
                      shrinkWrap: true,
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
                            'Mera seç',
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
                                  label: 'Check-in Yap',
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
                          Text(
                            sheetSpot.description?.trim().isNotEmpty == true
                                ? sheetSpot.description!
                                : 'Açıklama yok. Bu merayı bilen yazsın.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.foam.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RecentCheckinsRow(checkins: sheetCheckins),
                        ] else ...[
                          Text(
                            'Haritada bir meraya dokun. Hızlı bilgi burada.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.foam.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _EmptySheetHints(fishDensityTitle: fishDensityTitle),
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
      'friends' => ('Takipçi', AppColors.pinFriends),
      'private' => ('Gizli', AppColors.pinPrivate),
      'vip' => ('VIP', AppColors.pinVip),
      _ => ('Public', AppColors.pinPublic),
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
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LayerToggleGroup extends StatelessWidget {
  final bool showSpots;
  final bool showShops;
  final bool showWeather;
  final VoidCallback onToggleSpots;
  final VoidCallback onToggleShops;
  final VoidCallback onToggleWeather;

  const _LayerToggleGroup({
    required this.showSpots,
    required this.showShops,
    required this.showWeather,
    required this.onToggleSpots,
    required this.onToggleShops,
    required this.onToggleWeather,
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
        const SizedBox(height: 10),
        _LayerToggleButton(
          icon: Icons.cloud_outlined,
          label: 'Hava',
          active: showWeather,
          onPressed: onToggleWeather,
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
                  fontSize: 10,
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

class _SpotSheetHeader extends StatelessWidget {
  final SpotModel spot;
  final int activeCount;
  final bool hasMuhtar;

  const _SpotSheetHeader({
    required this.spot,
    required this.activeCount,
    required this.hasMuhtar,
  });

  @override
  Widget build(BuildContext context) {
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
              '$count aktif check-in',
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
            color: AppColors.foam.withValues(alpha: 0.70),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.foam,
            fontWeight: FontWeight.w900,
            fontSize: 13,
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

class _RecentCheckinsRow extends StatelessWidget {
  final List<CheckinModel> checkins;
  const _RecentCheckinsRow({required this.checkins});

  @override
  Widget build(BuildContext context) {
    if (checkins.isEmpty) {
      return Text(
        'Son check-in yok.',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.foam.withValues(alpha: 0.70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Son Check-in\'ler',
          style: AppTextStyles.h3.copyWith(color: AppColors.foam, fontSize: 14),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: checkins.length.clamp(0, 10),
            separatorBuilder: (_, indexValue) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final c = checkins[i];
              final t = _formatAgo(c.createdAt);
              final active = !c.isStale;
              final bg = active
                  ? AppColors.teal.withValues(alpha: 0.18)
                  : AppColors.pinPrivate.withValues(alpha: 0.14);
              final border = active
                  ? AppColors.teal.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.10);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.foam.withValues(
                        alpha: active ? 0.18 : 0.10,
                      ),
                      child: Text(
                        '🎣',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.foam.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t,
                      style: TextStyle(
                        color: AppColors.foam.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 2) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }
}

class _EmptySheetHints extends StatelessWidget {
  final String fishDensityTitle;
  const _EmptySheetHints({required this.fishDensityTitle});

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
          const Icon(Icons.info_outline, color: Color(0xFFB8C7DA), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Seçilen merada: $fishDensityTitle. Aktif check-in ve hava burada görünür.',
              style: TextStyle(
                color: AppColors.foam.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
