import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// FCM + yerel bildirim servisi.
/// M-09 Push Bildirim Sistemi — MVP_PLAN.md referans.
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // İzin iste
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Yerel bildirim kanalı (Android)
    const androidChannel = AndroidNotificationChannel(
      'balikci_channel',
      'Balıkçı Bildirimleri',
      description: 'Check-in, hava ve puan bildirimleri',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // Foreground mesaj dinleyici
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  static Future<String?> getFcmToken() => _messaging.getToken();

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'balikci_channel',
          'Balıkçı Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
