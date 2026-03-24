import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/notification_service.dart';

class StepNotification extends StatefulWidget {
  const StepNotification({super.key});

  @override
  State<StepNotification> createState() => _StepNotificationState();
}

class _StepNotificationState extends State<StepNotification>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  bool _busy = false;
  AuthorizationStatus? _authorizationStatus;

  bool get _notificationAllowed {
    final s = _authorizationStatus;
    return s == AuthorizationStatus.authorized ||
        s == AuthorizationStatus.provisional;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshFromOs());
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
      unawaited(_refreshFromOs());
    }
  }

  Future<void> _refreshFromOs() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() => _authorizationStatus = settings.authorizationStatus);
    } catch (_) {
      // Sessiz
    }
  }

  Future<void> _onPressAllowNotifications() async {
    if (_busy || _notificationAllowed) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);

    try {
      await _refreshFromOs();
      if (!mounted) return;
      if (_notificationAllowed) {
        setState(() => _busy = false);
        return;
      }

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (!mounted) return;
      setState(() => _authorizationStatus = settings.authorizationStatus);

      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        try {
          await NotificationService.syncFcmToken();
        } catch (e) {
          messenger?.showSnackBar(
            SnackBar(
              content: Text('Bildirim izni tamam, ancak token kaydedilemedi: $e'),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (!mounted) return;
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim izni verilmedi. Sonra ayarlardan açabilirsiniz.',
            ),
            backgroundColor: AppColors.muted,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Bildirim izni istenirken hata: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        unawaited(_refreshFromOs());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allowed = _notificationAllowed;

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
            onPressed: (allowed || _busy) ? null : _onPressAllowNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: Text(
              allowed ? 'Bildirim izni verildi' : 'Bildirimlere İzin Ver',
            ),
          ),
        ],
      ),
    );
  }
}
