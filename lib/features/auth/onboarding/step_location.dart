import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:balikci_app/app/theme.dart';

class StepLocation extends StatefulWidget {
  const StepLocation({super.key});

  @override
  State<StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends State<StepLocation>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  /// OS veya bu oturumda basariyla verildi.
  bool _granted = false;
  bool _busy = false;

  bool get _locationAllowed =>
      _granted ||
      _permissionIsGranted(
        // init'te henuz okunmadiysa false; build sirasinda guncellenir
        _lastKnownPermission,
      );

  LocationPermission? _lastKnownPermission;

  static bool _permissionIsGranted(LocationPermission? p) {
    if (p == null) return false;
    return p == LocationPermission.whileInUse ||
        p == LocationPermission.always;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshPermissionFromOs());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissionFromOs());
    }
  }

  Future<void> _refreshPermissionFromOs() async {
    try {
      final p = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _lastKnownPermission = p;
        if (_permissionIsGranted(p)) {
          _granted = true;
        }
      });
    } catch (_) {
      // Sessiz; kullanici butonla tekrar dener
    }
  }

  void _showMessage(
    BuildContext context,
    String message,
    Color color, {
    ScaffoldMessengerState? messenger,
  }) {
    final m = messenger ?? ScaffoldMessenger.maybeOf(context);
    if (m != null) {
      m.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konum'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _requestLocationPermission() async {
    if (_locationAllowed || _busy) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() => _busy = true);
    try {
      await _refreshPermissionFromOs();
      if (!mounted) return;
      if (_locationAllowed) {
        setState(() => _busy = false);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konum kapalı'),
            content: const Text(
              'Cihazda konum (GPS) kapalı. Harita ve yakındaki meralar için konumu açman gerekir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _openLocationSettings();
                },
                child: const Text('Ayarlara git'),
              ),
            ],
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      setState(() => _lastKnownPermission = permission);

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage(
            context,
            'Konum izni reddedildi. İstersen atlayabilir veya ayarlardan izin verebilirsin.',
            AppColors.danger,
            messenger: messenger,
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konum izni kapalı'),
            content: const Text(
              'Konum izni kalıcı olarak reddedilmiş. Uygulama ayarlarından izin verebilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _openAppSettings();
                },
                child: const Text('Uygulama ayarları'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _granted = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allowed = _locationAllowed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_on,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 32),
          const Text(
            'Yakınındaki Meraları Gör',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Konumunu paylaşarak yakınındaki balık meralarını ve anlık durumları görebilirsin.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: (allowed || _busy) ? null : () => _requestLocationPermission(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: Text(allowed ? 'Konum izni verildi' : 'Konum İznini Ver'),
          ),
        ],
      ),
    );
  }
}
