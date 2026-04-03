import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/core/services/supabase_service.dart';

/// Arka planda gelen mesajları işleyen global fonksiyon.
/// Uygulama kapalıyken (terminated) veya arka plandayken (background) çalışır.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM Arka plan mesajı alındı: ${message.messageId}');
}

/// M-09 Push Bildirim Sistemi — MVP_PLAN.md referans.
/// Firebase Cloud Messaging (FCM) ve yerel bildirimleri yöneten servis sınıfı.
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Bildirim iznini uygulama açılışında sormuyoruz.
    // İzin isteği sadece onboarding akışındaki butonla yapılacak.

    // Arka plan dinleyici ayarla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Yerel bildirim kanalı (Android)
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

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      // Uygulama açıkken gösterilen lokal bildirime tıklanınca yönlendir.
      onDidReceiveNotificationResponse: (details) {
        _navigate(_routeForType(details.payload));
      },
    );

    // Foreground mesaj dinleme
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Uygulama arka plandayken bildirime tıklanınca yönlendir.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Uygulama tamamen kapalıyken bildirime tıklanınca yönlendir.
    // addPostFrameCallback ile router hazır olana kadar bekle.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMessage(message);
        });
      }
    });

    // Token alma ve Supabase'e kaydetme:
    // - Kullanıcı izin vermediyse token olmayabilir, bu yüzden burada sadece izin durumu authorized/provisional ise senkronlarız.
    // - İzin onboarding'de verildiğinde StepNotification tarafında tekrar sync tetiklenir.
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await syncFcmToken();
    }

    // Token yenilendiğinde tekrar kaydet
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToSupabase(newToken);
    });
  }

  static Future<String?> getFcmToken() => _messaging.getToken();

  /// FCM data['type'] değerine göre hedef route döner.
  static String _routeForType(String? type) => switch (type) {
    'checkin' => '/map',
    'fish_log' => '/log',
    'rank' => '/rank',
    'vote' => '/map',
    _ => '/home',
  };

  /// appNavigatorKey üzerinden go_router ile yönlendir.
  static void _navigate(String route) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(route);
  }

  /// Bildirim mesajını işle ve uygun ekrana yönlendir.
  static void _handleMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    debugPrint('FCM yönlendirme: type=$type → ${_routeForType(type)}');
    _navigate(_routeForType(type));
  }

  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM Ön planda mesaj alındı. ID: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    // payload olarak type gönder; bildirime tıklanınca onDidReceiveNotificationResponse tetiklenir.
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
      payload: message.data['type'] as String?,
    );
  }

  /// FCM token'ını alır ve Supabase'e gönderir.
  static Future<void> syncFcmToken() async {
    try {
      final token = await getFcmToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('FCM Token alınamadı: $e');
    }
  }

  /// Token'ı Supabase 'users' tablosundaki 'fcm_token' sütununa yazar.
  /// İşlemin başarılı olması için oturum açılmış olmalıdır.
  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = SupabaseService.auth.currentUser;
      if (user != null) {
        await SupabaseService.client
            .from('users')
            .update({'fcm_token': token})
            .eq('id', user.id);
        debugPrint('FCM Token Supabase user tablosuna kaydedildi.');
      } else {
        debugPrint('Kullanıcı oturumu yok, token DB\'ye kaydedilmedi.');
      }
    } catch (e) {
      debugPrint('FCM Supabase kayıt hatası: $e');
    }
  }
}
