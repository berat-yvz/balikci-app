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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum sec'),
        actions: [
          IconButton(
            onPressed: _confirm,
            icon: const Icon(Icons.check),
            tooltip: 'Sec',
          ),
        ],
      ),
      body: FlutterMap(
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
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
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
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.place,
                    color: AppColors.pinPublic,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
