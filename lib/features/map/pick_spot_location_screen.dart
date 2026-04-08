import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:balikci_app/app/theme.dart';

/// Haritada dokunarak mera koordinati secmek icin tam ekran (H4).
class PickSpotLocationScreen extends StatefulWidget {
  final LatLng? initial;

  const PickSpotLocationScreen({super.key, this.initial});

  @override
  State<PickSpotLocationScreen> createState() => _PickSpotLocationScreenState();
}

class _PickSpotLocationScreenState extends State<PickSpotLocationScreen> {
  static final LatLng _fallback = LatLng(41.015, 28.979);

  final MapController _mapController = MapController();
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  void _confirm() {
    final p = _picked;
    if (p == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Haritada bir nokta secin')));
      return;
    }
    context.pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final center = _picked ?? widget.initial ?? _fallback;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Konum Seç')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              onTap: (_, point) {
                setState(() => _picked = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 18,
                maxNativeZoom: 18,
                tileSize: 256,
                keepBuffer: 2,
                userAgentPackageName: 'com.balikci.app',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.place,
                        color: AppColors.pinPublic,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Üst hint banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      color: AppColors.teal, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _picked == null
                          ? 'Mera konumunu işaretlemek için haritaya dokun'
                          : 'Konum seçildi. Onaylamak için aşağıdaki butona bas.',
                      style: const TextStyle(
                        color: AppColors.foam,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alt onay butonu
          Positioned(
            bottom: bottomPad + 16,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _picked != null ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _picked != null
                      ? AppColors.teal
                      : AppColors.muted,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Bu Konumu Onayla',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
