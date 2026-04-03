import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/user_model.dart';

/// Kullanıcı profili repository — users ve follows tabloları.
class UserRepository {
  final SupabaseClient _db = SupabaseService.client;

  /// Belirli bir kullanıcının profilini döner.
  /// Kayıt bulunamazsa `null` döner.
  Future<UserModel?> getProfile(String userId) async {
    try {
      final data = await _db
          .from('users')
          .select('id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw Exception(
        'Kullanıcı profili alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Kullanıcı profili alınamadı: $e');
    }
  }

  /// Profil güncelleme — yalnızca belirtilen alanlar güncellenir.
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;

    try {
      await _db.from('users').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Profil güncellenirken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Profil güncellenemedi: $e');
    }
  }

  /// Toplam puana göre liderlik tablosu.
  ///
  /// [regionFilter] şu an için sadece imza seviyesinde tutuluyor; ileride
  /// kullanıcı bölge alanı eklendiğinde sorguya dahil edilecek.
  Future<List<UserModel>> getLeaderboard({
    String? regionFilter,
    int limit = 50,
  }) async {
    try {
      final response = await _db
          .from('users')
          .select('id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at')
          .order('total_score', ascending: false)
          .limit(limit);
      final users = response.map<UserModel>(UserModel.fromJson).toList();

      // Şimdilik bölge filtresi olmadığı için backend tarafında filtre yok.
      // Gelecekte kullanıcıya ait bölge bilgisi eklendiğinde burada
      // regionFilter ile daraltılabilir.
      return users;
    } on PostgrestException catch (e) {
      throw Exception(
        'Liderlik tablosu alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Liderlik tablosu alınamadı: $e');
    }
  }

  /// Belirli bir kullanıcının takipçi sayısı.
  Future<int> getFollowerCount(String userId) async {
    try {
      final response = await _db
          .from('follows')
          .select('id')
          .eq('following_id', userId);
      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception('Takipçi sayısı alınırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Takipçi sayısı alınamadı: $e');
    }
  }

  /// Belirli bir kullanıcının takip ettiği kişi sayısı.
  Future<int> getFollowingCount(String userId) async {
    try {
      final response = await _db
          .from('follows')
          .select('id')
          .eq('follower_id', userId);
      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception(
        'Takip edilen sayısı alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Takip edilen sayısı alınamadı: $e');
    }
  }

  /// Mevcut kullanımları korumak için FCM token güncelleme yardımcı metodu.
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _db.from('users').update({'fcm_token': token}).eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception(
        'Bildirim anahtarı güncellenirken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Bildirim anahtarı güncellenemedi: $e');
    }
  }
}
