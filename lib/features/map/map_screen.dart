import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/spot_repository.dart';
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
  final MapController _mapController = MapController();

  List<SpotModel> _spots = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCacheAndLoad();
  }

  Future<void> _initializeCacheAndLoad() async {
    try {
      await FMTCObjectBoxBackend().initialise();
    } catch (_) {
      // Cache backend daha once baslatildiysa veya platformda kisit varsa sessiz devam.
    }
    await _loadSpots();
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
    } catch (e) {
      // Remote hata verirse local cache ile fallback.
      final cached = await _repository.getCachedSpots();
      setState(() {
        _spots = cached;
        _error = cached.isEmpty ? 'Meralar yuklenemedi.' : null;
      });
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

  List<Marker> _buildMarkers() {
    return _spots
        .map(
          (spot) => Marker(
            point: LatLng(spot.lat, spot.lng),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _openSpotDetail(spot),
              child: SpotMarker(privacyLevel: spot.privacyLevel),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tileProvider = FMTCStore('balikci_map_h3').getTileProvider();

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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.balikciapp.mobile',
                tileProvider: tileProvider,
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
