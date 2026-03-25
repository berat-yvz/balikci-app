import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:balikci_app/data/repositories/checkin_repository.dart';
import 'package:balikci_app/features/map/spot_detail_sheet.dart';
import 'package:balikci_app/features/map/widgets/spot_marker.dart';

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
  final MapController _mapController = MapController();

  /// FMTC basarisiz olursa ag uzerinden [NetworkTileProvider] (karo gorunur kalir).
  TileProvider _tileProvider = NetworkTileProvider();

  List<SpotModel> _spots = const [];
  Map<String, List<CheckinModel>> _activeCheckinsBySpotId = const {};
  bool _isLoading = true;
  bool _myLocationBusy = false;
  String? _error;

  bool _checkingCheckins = false;
  Timer? _checkinPollTimer;
  RealtimeChannel? _checkinsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _initializeCacheAndLoad();
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

  void _openSpotDetail(SpotModel spot) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SpotDetailSheet(spot: spot),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_myLocationBusy) return;
    setState(() => _myLocationBusy = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konum alinamadi. Izin veya GPS acik mi kontrol edin.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } finally {
      if (mounted) setState(() => _myLocationBusy = false);
    }
  }

  List<Marker> _buildMarkers() {
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _openSpotDetail(spot),
              child: _buildSpotMarker(spot),
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
  void dispose() {
    unawaited(_checkinsRealtimeChannel?.unsubscribe());
    _checkinsRealtimeChannel = null;
    _checkinPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harita'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSpots,
            icon: const Icon(Icons.refresh),
            tooltip: 'Meralari yenile',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'map_my_location',
            tooltip: 'Konumum',
            onPressed:
                (_isLoading || _myLocationBusy) ? null : _goToMyLocation,
            child: _myLocationBusy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'map_add_spot',
            onPressed: _isLoading
                ? null
                : () async {
                    final added = await context.push<bool>('/map/add-spot');
                    if (!mounted) return;
                    if (added == true) await _loadSpots();
                  },
            icon: const Icon(Icons.add),
            label: const Text('Mera ekle'),
          ),
        ],
      ),
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.balikciapp.balikci_app',
                tileProvider: _tileProvider,
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
                        border: Border.all(color: Colors.white, width: 2),
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null && !_isLoading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
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
