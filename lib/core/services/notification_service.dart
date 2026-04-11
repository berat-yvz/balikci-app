import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/repositories/user_repository.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Yardımcı: mesaj türüne göre route belirle
// ──────────────────────────────────────────────────────────────────────────────

String _routeForType(String? type) => switch (type?.toLowerCase()) {
  'checkin' => AppRoutes.map,
  'vote' => AppRoutes.map,
  'rank' => AppRoutes.rank,
  'follow' => AppRoutes.profile,
  'fish_log' => AppRoutes.fishLog,
  _ => AppRoutes.home,
};

// ──────────────────────────────────────────────────────────────────────────────
// Arka plan / terminated handler — top-level fonksiyon zorunlu
// ──────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM arka plan: ${message.messageId}');

  // Notification field varsa Android zaten gösterir.
  // Data-only mesajlar için yerel bildirim oluştur.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] as String? ?? 'Balıkçı';
    final body = message.data['body'] as String? ?? '';
    if (body.isNotEmpty) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await plugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'balikci_channel',
            'Balıkçı Bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode({
          'type': message.data['type'],
          if (message.data.containsKey('spot_id'))
            'spot_id': message.data['spot_id'],
        }),
      );
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// M-09 Push Bildirim Servisi
// ──────────────────────────────────────────────────────────────────────────────

/// Firebase Cloud Messaging + yerel bildirim yönetimi.
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Arka plan handler (uygulama kapalı / background)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android bildirim kanalı
    const androidChannel = AndroidNotificationChannel(
      'balikci_channel',
      'Balıkçı Bildirimleri',
      description: 'Check-in, hava ve puan bildirimleri',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Yerel bildirim başlatma
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        _navigateFromPayload(details.payload);
      },
    );

    // Ön planda mesaj dinleme
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Arka planda iken bildirime tıklanma
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Uygulama kapalıyken bildirime tıklanma
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMessage(message);
        });
      }
    });

    // İzin zaten verilmişse token senkronla
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await syncFcmToken();
    }

    // Token yenileme
    _messaging.onTokenRefresh.listen(_saveTokenToSupabase);
  }

  static Future<String?> getFcmToken() => _messaging.getToken();

  /// Uygulama ön plandayken gelen FCM mesajını işle.
  /// Hem `notification` field'lı hem data-only mesajları destekler.
  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM ön plan: ${message.messageId}');

    // notification field varsa onu kullan; yoksa data'dan çek
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Balıkçı';
    final body = message.notification?.body ??
        message.data['body'] as String?;

    if (body == null || body.isEmpty) return;

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'balikci_channel',
          'Balıkçı Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode({
        'type': message.data['type'],
        if (message.data.containsKey('spot_id'))
          'spot_id': message.data['spot_id'],
      }),
    );
  }

  /// Bildirime tıklanınca uygun sayfaya yönlendir.
  /// checkin / vote türündeyse spot_id ile mera sayfası açılır.
  static void _handleMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final spotId = message.data['spot_id'] as String?;
    debugPrint('FCM yönlendirme: type=$type, spotId=$spotId');
    if (spotId != null && (type == 'checkin' || type == 'vote')) {
      _navigate(AppRoutes.map, extra: spotId);
    } else {
      _navigate(_routeForType(type));
    }
  }

  /// JSON payload içindeki type ve spot_id'ye göre yönlendir.
  /// Eski format (sadece tip string) da desteklenir.
  static void _navigateFromPayload(String? payload) {
    if (payload == null) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final type = map['type'] as String?;
      final spotId = map['spot_id'] as String?;
      if (spotId != null && (type == 'checkin' || type == 'vote')) {
        _navigate(AppRoutes.map, extra: spotId);
      } else {
        _navigate(_routeForType(type));
      }
    } catch (_) {
      // Eski format: payload direkt type string
      _navigate(_routeForType(payload));
    }
  }

  static void _navigate(String route, {Object? extra}) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(route, extra: extra);
  }

  /// FCM token'ı alır ve Supabase'e yazar.
  static Future<void> syncFcmToken() async {
    try {
      final token = await getFcmToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('FCM Token alınamadı: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = SupabaseService.auth.currentUser;
      if (user == null) return;
      await UserRepository().updateFcmToken(user.id, token);
      debugPrint('FCM Token kaydedildi.');
    } catch (e) {
      debugPrint('FCM Token Supabase kayıt hatası: $e');
    }
  }
}
