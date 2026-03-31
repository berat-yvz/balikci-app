import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/notification_model.dart';

/// Bildirim repository — notifications tablosu.
class NotificationRepository {
  final SupabaseClient _db = SupabaseService.client;

  Future<List<NotificationModel>> getMyNotifications({
    int limit = 50,
  }) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Bildirimler için önce giriş yapmalısın.');
    }

    try {
      final response = await _db
          .from('notifications')
          .select()
          .eq('user_id', currentUserId)
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
      throw Exception('Bildirim okundu işareti güncellenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Bildirim okundu işareti güncellenemedi: $e');
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
          .eq('user_id', currentUserId);
    } on PostgrestException catch (e) {
      throw Exception('Tüm bildirimler okunamadı: ${e.message}');
    } catch (e) {
      throw Exception('Tüm bildirimler okunamadı: $e');
    }
  }

  Future<int> getUnreadCount() async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      return 0;
    }

    try {
      final response = await _db
          .from('notifications')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('read', false)
          .limit(10000);

      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception('Okunmamış bildirim sayısı alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Okunmamış bildirim sayısı alınamadı: $e');
    }
  }
}

