import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/user_model.dart';

/// Haftalık sıralama için kullanıcı + aktivite girişi.
class WeeklyRankEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final String rank;
  final int checkinCount;

  const WeeklyRankEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.rank,
    required this.checkinCount,
  });
}

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

  /// Son 7 gündeki check-in sayısına göre haftalık sıralama.
  ///
  /// Checkins tablosundan son 7 günün aktivitesi kullanılır;
  /// `total_score` yerine haftalık etkinlik metriği gösterilir.
  Future<List<WeeklyRankEntry>> getWeeklyLeaderboard({int limit = 50}) async {
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(days: 7));
      final response = await _db
          .from('checkins')
          .select('user_id, users!inner(id, username, avatar_url, rank)')
          .gte('created_at', since.toIso8601String())
          .eq('is_hidden', false)
          .limit(500); // fazlasını çekip istemci tarafında say

      final raw = (response as List).cast<Map<String, dynamic>>();

      // Kullanıcı bazlı check-in sayısını topla
      final counts = <String, int>{};
      final userMeta = <String, Map<String, dynamic>>{};
      for (final row in raw) {
        final uid = row['user_id'] as String;
        counts[uid] = (counts[uid] ?? 0) + 1;
        userMeta[uid] ??= (row['users'] as Map<String, dynamic>);
      }

      // Sırala
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((e) {
        final meta = userMeta[e.key]!;
        return WeeklyRankEntry(
          userId: e.key,
          username: (meta['username'] as String?) ?? 'Balıkçı',
          avatarUrl: meta['avatar_url'] as String?,
          rank: meta['rank'] as String? ?? 'acemi',
          checkinCount: e.value,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Haftalık sıralama alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Haftalık sıralama alınamadı: $e');
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
