import 'dart:async';

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
import 'package:balikci_app/data/repositories/shop_repository.dart';
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

  bool _checkingCheckins = false;
  Timer? _checkinPollTimer;
  RealtimeChannel? _checkinsRealtimeChannel;

  SpotModel? _sheetSpot;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  int _navIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  List<SpotModel> _searchResults = const [];

  WeatherModel? _spotWeather;
  bool _weatherLoading = false;

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
    _sheetController.dispose();
    _searchController.dispose();
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
    _checkinPollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      setState(() {});
    });

    _startCheckinsRealtime();
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

  void _openCheckinForSpot(SpotModel spot) {
    context.push('/checkin/${spot.id}');
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

  List<Marker> _buildMarkers() {
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            width: 44,
            height: 44,
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
            child: Icon(
              Icons.storefront,
              color: Colors.orange,
              size: 32,
            ),
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
    final weatherTitle = weather?.fishingSummary?.trim().isNotEmpty == true
        ? weather!.fishingSummary!.trim()
        : (sheetSpot == null
            ? 'Bir mera seç'
            : 'Hava verisi yükleniyor...');
    final windKmh = weather != null ? weather.windKmh.round().toString() : '—';
    final tempC = weather != null ? weather.tempCelsius.round().toString() : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 10,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.balikciapp.balikci_app',
                  tileProvider: _tileProvider,
                ),
                if (_showShops)
                  MarkerLayer(
                    markers: _buildShopMarkers(),
                  ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: _buildMarkers(),
                    maxClusterRadius: 55,
                    size: const Size(42, 42),
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
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

          // Üst: Arama + Hava kartı
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        hintText: 'Mera ara...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white70),
                        suffixIcon: Consumer(
                          builder: (context, ref, _) {
                            final unreadAsync = ref.watch(
                              unreadCountProvider,
                            );

                            Widget iconForCount(int count) {
                              final showBadge = count > 0;
                              return Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.notifications_none,
                                    color: Colors.white70,
                                  ),
                                  if (showBadge)
                                    Positioned(
                                      right: -8,
                                      top: -8,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          count > 99 ? '99+' : '$count',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
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
                                onPressed: () => context.push('/notifications'),
                                icon: iconForCount(count),
                              ),
                              loading: () => IconButton(
                                tooltip: 'Bildirimler',
                                onPressed: () => context.push('/notifications'),
                                icon: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white70,
                                ),
                              ),
                              error: (error, stackTrace) => IconButton(
                                tooltip: 'Bildirimler',
                                onPressed: () => context.push('/notifications'),
                                icon: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white70,
                                ),
                              ),
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                          itemBuilder: (context, idx) {
                            final spot = _searchResults[idx];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                _searchController.text = spot.name;
                                _selectSpot(spot);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.white70, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        spot.name,
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push('/weather'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    weatherTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_weatherLoading)
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.air, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  '$windKmh km/h',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.thermostat, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  '$tempC°C',
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sheetSpot == null
                                  ? 'Mera seçince hava burada güncellenir'
                                  : 'Hava detayı için dokun',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sağ: Harita aksiyonları (H4: mera ekle, konumuma git)
          Positioned(
            right: 16,
            bottom: 16 + kBottomNavigationBarHeight,
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

          // Top-right: Dükkanları göster/gizle
          Positioned(
            right: 16,
            top: 120,
            child: _MapActionButton(
              icon: Icons.storefront,
              tooltip: _showShops ? 'Dükkanları gizle' : 'Dükkanları göster',
              onPressed: () {
                setState(() => _showShops = !_showShops);
              },
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // Alt: Draggable sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.16,
              minChildSize: 0.12,
              // Üstteki arama/hava kartıyla çakışmayı azaltmak için max'i düşürdük.
              maxChildSize: 0.45,
              snap: true,
              snapSizes: const [0.16, 0.32, 0.45],
              builder: (context, scrollController) {
                final bottomPad = MediaQuery.of(context).padding.bottom;
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: bottomPad + kBottomNavigationBarHeight),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.70),
                    elevation: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: Container(
                            height: 5,
                            width: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sheetSpot?.name ?? 'Mera seç',
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.water_drop,
                                color: Colors.lightBlueAccent),
                            const SizedBox(width: 8),
                            Text(
                              fishDensityTitle,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(
                              '${activeCount.toString()} Kişi Balık Tutuyor',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        if (sheetSpot != null)
                          Text(
                            sheetSpot.description?.trim().isNotEmpty == true
                                ? sheetSpot.description!
                                : 'Açıklama yok.',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white70,
                            ),
                          )
                        else
                          const SizedBox.shrink(),

                        const SizedBox(height: 14),
                        if (sheetSpot != null)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openCheckinForSpot(sheetSpot),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Check-in'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openDirectionsForSpot(sheetSpot),
                                  icon: const Icon(Icons.directions),
                                  label: const Text('Yol tarifi'),
                                ),
                              ),
                            ],
                          ),
                        if (sheetSpot != null && isOwner) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openEditForSpot(sheetSpot),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Düzenle'),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                        Text(
                          sheetSpot == null
                              ? 'Haritada bir meraya dokunarak detaylara bakabilirsin.'
                              : 'Aşağı kaydırıp kapatabilirsin.',
                          style: const TextStyle(color: Colors.white70),
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
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white70,
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          switch (i) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/fish-log');
              break;
            case 2:
              final spot = _sheetSpot;
              if (spot == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('L\u00fctfen \u00f6nce bir mera se\u00e7in.'),
                  ),
                );
                break;
              }
              _openCheckinForSpot(spot);
              break;
            case 3:
              context.go('/rank');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Harita',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            label: 'G\u00fcnl\u00fck',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.anchor_outlined),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'S\u0131ralama',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
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
