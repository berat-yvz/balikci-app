import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:balikci_app/app/theme.dart';

class StepLocation extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const StepLocation({
    super.key,
    required this.onPermissionGranted,
  });

  Future<void> _requestLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _showSnackbar(context, 'Konum servisleri kapalı. Lütfen açın.', AppColors.danger);
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          _showSnackbar(context, 'Konum izni reddedildi.', AppColors.danger);
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showSnackbar(context, 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verebilirsiniz.', AppColors.danger);
      }
      return;
    }

    if (context.mounted) {
      _showSnackbar(context, 'Konum izni başarıyla verildi!', AppColors.pinPublic);
      onPermissionGranted();
    }
  }

  void _showSnackbar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
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
