import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:balikci_app/app/theme.dart';

class StepLocation extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const StepLocation({
    super.key,
    required this.onPermissionGranted,
  });

  void _showMessage(BuildContext context, String message, Color color) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
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

  Future<void> _openLocationSettings(BuildContext context) async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings(BuildContext context) async {
    await Geolocator.openAppSettings();
  }

  Future<void> _requestLocationPermission(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return;
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
                await _openLocationSettings(context);
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

    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        _showMessage(
          context,
          'Konum izni reddedildi. İstersen atlayabilir veya ayarlardan izin verebilirsin.',
          AppColors.danger,
        );
      }
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return;
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
                await _openAppSettings(context);
              },
              child: const Text('Uygulama ayarları'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    _showMessage(
      context,
      'Konum izni hazır. Teşekkürler!',
      AppColors.pinPublic,
    );
    onPermissionGranted();
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _requestLocationPermission(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Konum İznini Ver'),
          ),
        ],
      ),
    );
  }
}
