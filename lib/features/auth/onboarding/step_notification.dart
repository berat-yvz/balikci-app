import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:balikci_app/app/theme.dart';

class StepNotification extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const StepNotification({
    super.key,
    required this.onPermissionGranted,
  });

  Future<void> _requestNotificationPermission(BuildContext context) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (context.mounted) {
        _showSnackbar(context, 'Bildirim izni başarıyla verildi!', AppColors.pinPublic);
        onPermissionGranted();
      }
    } else {
      if (context.mounted) {
        _showSnackbar(context, 'Bildirim izni verilmedi. Sonra ayarlardan açabilirsiniz.', AppColors.muted);
        onPermissionGranted(); // Reddetse de devam etsin ki onboarding bitirilebilsin
      }
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
            Icons.notifications,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 32),
          const Text(
            'Balık Haberlerini Kaçırma',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Yakınında balık tutulduğunda, favori meranda hareket olduğunda seni haberdar edelim.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => _requestNotificationPermission(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Bildirimlere İzin Ver'),
          ),
        ],
      ),
    );
  }
}
