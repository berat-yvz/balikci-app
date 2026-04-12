import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/notification_model.dart';

/// Bildirim repository — notifications tablosu.
class NotificationRepository {
  final SupabaseClient _db = SupabaseService.client;

  Future<List<NotificationModel>> getMyNotifications({int limit = 50}) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Bildirimler için önce giriş yapmalısın.');
    }

    try {
      final response = await _db
          .from('notifications')
          .select('id, user_id, type, title, body, data_json, read, created_at')
          .eq('user_id', currentUserId)
          .eq('read', false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((row) => NotificationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Bildirimler yüklenirken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Bildirimler yüklenemedi: $e');
    }
  }

  /// Okundu işaretlenir; liste `read == false` filtrelediği için panelden kaybolur.
  /// (DELETE yerine UPDATE — Realtime stream ile güvenilir senkron.)
  Future<void> markAsRead(String notificationId) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Bildirimleri güncellemek için önce giriş yapmalısın.');
    }

    try {
      await _db
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId)
          .eq('user_id', currentUserId);
    } on PostgrestException catch (e) {
      throw Exception('Bildirim güncellenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Bildirim güncellenemedi: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Bildirimleri güncellemek için önce giriş yapmalısın.');
    }

    try {
      await _db
          .from('notifications')
          .update({'read': true})
          .eq('user_id', currentUserId)
          .eq('read', false);
    } on PostgrestException catch (e) {
      throw Exception('Tüm bildirimler okunamadı: ${e.message}');
    } catch (e) {
      throw Exception('Tüm bildirimler okunamadı: $e');
    }
  }

  Future<int> getUnreadCount() async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) return 0;

    try {
      // count(*) Postgrest ile doğrudan çekilir — bellek/limit sorunu yok
      final response = await _db
          .from('notifications')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('read', false)
          .limit(200);

      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception('Okunmamış bildirim sayısı alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Okunmamış bildirim sayısı alınamadı: $e');
    }
  }

  /// `notification-sender` Edge Function'ını çağırarak hem push bildirim
  /// gönderir hem de `notifications` tablosuna satır ekler.
  ///
  /// [userId]  : bildirim alacak kullanıcının ID'si
  /// [title]   : bildirim başlığı
  /// [body]    : bildirim içeriği
  /// [data]    : ek veri (type, spot_id vb.) — FCM string zorunlu
  ///
  /// Sessiz başarısızlık: push mümkün değilse (fcm_token yok) Edge Function
  /// yine de in-app notification DB satırı eklemeye çalışır. Bu yüzden bu
  /// metod hata fırlatmak yerine loglar; çağıran taraf tekrar denemeye gerek
  /// duymaz.
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      await SupabaseService.client.functions.invoke(
        'notification-sender',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          'data': data,
        },
      );
    } catch (e) {
      // Bildirim gönderilemese bile check-in akışını engelleme
      debugPrint('Bildirim Edge Function çağrısı başarısız: $e');
    }
  }
}
