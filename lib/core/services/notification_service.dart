import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
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
    await _localNotifications.initialize(initSettings);

    // Foreground mesaj dinleme
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

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

  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM Ön planda mesaj alındı. ID: ${message.messageId}');
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
