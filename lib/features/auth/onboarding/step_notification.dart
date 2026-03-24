import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/notification_service.dart';

class StepNotification extends StatefulWidget {
  final VoidCallback onPermissionGranted;

  const StepNotification({
    super.key,
    required this.onPermissionGranted,
  });

  @override
  State<StepNotification> createState() => _StepNotificationState();
}

class _StepNotificationState extends State<StepNotification> {
  bool _asked = false;

  Future<void> _onPressAllowNotifications() async {
    if (_asked) return;
    setState(() => _asked = true);
    try {
      await _requestNotificationPermission(context);
    } finally {
      if (mounted) setState(() => _asked = false);
    }
  }

  Future<void> _requestNotificationPermission(BuildContext context) async {
    // Async gap sonrası `context` ile ilgili lint hatası yaşamamak için
    // snackbar göndericiyi (ScaffoldMessenger) baştan capture ediyoruz.
    final messenger = ScaffoldMessenger.of(context);
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

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    // İzin verildikten hemen sonra token'ı alıp Supabase'e kaydedelim.
    if (granted) {
      await NotificationService.syncFcmToken();
      if (!mounted) return;
      _showSnackbar(
        messenger,
        'Bildirim izni başarıyla verildi!',
        AppColors.pinPublic,
      );
      widget.onPermissionGranted();
      return;
    }

    if (!mounted) return;
    _showSnackbar(
      messenger,
      'Bildirim izni verilmedi. Sonra ayarlardan açabilirsiniz.',
      AppColors.muted,
    );
    widget.onPermissionGranted(); // Reddetse de devam etsin ki onboarding bitirilebilsin
  }

  void _showSnackbar(
    ScaffoldMessengerState messenger,
    String message,
    Color color,
  ) {
    messenger.showSnackBar(
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
            onPressed: _asked ? null : _onPressAllowNotifications,
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
