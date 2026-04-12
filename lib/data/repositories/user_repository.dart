import 'dart:math' show min;

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
    this.avatarUrl,
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

  UserModel _userFromPublicRow(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    m.putIfAbsent('email', () => '');
    m.putIfAbsent('fcm_token', () => null);
    return UserModel.fromJson(m);
  }

  /// Toplam puana göre liderlik tablosu.
  ///
  /// [rankFilter] null iken önce `leaderboard_users` RPC; filtre varsa doğrudan `users`.
  Future<List<UserModel>> getLeaderboard({
    int limit = 50,
    String? rankFilter,
  }) async {
    final filter = rankFilter?.trim();
    if (filter != null && filter.isNotEmpty) {
      try {
        final response = await _db
            .from('users')
            .select(
              'id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at',
            )
            .eq('rank', filter)
            .order('total_score', ascending: false)
            .limit(limit);
        return (response as List)
            .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
            .toList();
      } on PostgrestException catch (e) {
        throw Exception(
          'Liderlik tablosu alınırken bir hata oluştu: ${e.message}',
        );
      } catch (e) {
        throw Exception('Liderlik tablosu alınamadı: $e');
      }
    }

    try {
      final dynamic raw = await _db.rpc(
        'leaderboard_users',
        params: {'limit_count': limit},
      );
      if (raw is List && raw.isNotEmpty) {
        try {
          return raw
              .map((row) => _userFromPublicRow(row as Map<String, dynamic>))
              .toList();
        } catch (_) {
          // RPC kolon tipi / şema farkı — REST’e düş
        }
      }
    } on PostgrestException catch (_) {
      // RPC yoksa veya şema henüz uygulanmadıysa tablo sorgusuna düş.
    }

    try {
      final response = await _db
          .from('users')
          .select(
            'id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at',
          )
          .order('total_score', ascending: false)
          .limit(limit);
      return response.map<UserModel>(UserModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Liderlik tablosu alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Liderlik tablosu alınamadı: $e');
    }
  }

  /// Genel listede 1 tabanlı sıra (aynı puanda üstteki sayısı + 1).
  Future<int?> getMyLeaderboardRankPosition(String userId) async {
    try {
      final dynamic raw = await _db.rpc(
        'my_leaderboard_rank',
        params: {'check_user_id': userId},
      );
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
    } on PostgrestException catch (_) {
      // RPC yoksa: profil puanı ile yaklaşık sıra
    }

    try {
      final row = await _db
          .from('users')
          .select('total_score')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      final myScore = UserModel.coerceToInt(row['total_score']);
      final higher = await _db
          .from('users')
          .select('id')
          .gt('total_score', myScore);
      return (higher as List).length + 1;
    } on PostgrestException catch (e) {
      throw Exception('Sıra numarası alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Sıra numarası alınamadı: $e');
    }
  }

  /// Sosyal keşif: uygulamaya kayıtlı tüm balıkçılar (makul üst sınır).
  Future<List<UserModel>> getAllRegisteredAnglers({int limit = 2000}) async {
    try {
      final dynamic raw = await _db.rpc(
        'all_registered_anglers',
        params: {'limit_count': limit},
      );
      if (raw is List && raw.isNotEmpty) {
        try {
          return raw
              .map((row) => _userFromPublicRow(row as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
    } on PostgrestException catch (_) {}

    try {
      final response = await _db
          .from('users')
          .select(
            'id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at',
          )
          .order('username', ascending: true)
          .limit(limit);
      return response.map<UserModel>(UserModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception('Balıkçı listesi alınırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Balıkçı listesi alınamadı: $e');
    }
  }

  /// Birden fazla kullanıcı profilini tek seferde döner (sıra [ids] ile uyumlu).
  Future<List<UserModel>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final unique = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (seen.add(id)) unique.add(id);
    }
    try {
      const chunkSize = 100;
      final out = <UserModel>[];
      for (var i = 0; i < unique.length; i += chunkSize) {
        final end = min(i + chunkSize, unique.length);
        final part = unique.sublist(i, end);
        final response = await _db
            .from('users')
            .select(
              'id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at',
            )
            .inFilter('id', part);
        for (final row in response as List) {
          out.add(UserModel.fromJson(row as Map<String, dynamic>));
        }
      }
      final byId = {for (final u in out) u.id: u};
      return unique.map((id) => byId[id]).whereType<UserModel>().toList();
    } on PostgrestException catch (e) {
      throw Exception('Profiller alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Profiller alınamadı: $e');
    }
  }

  /// Bu coğrafi kutuda en az bir mera kaydı olan kullanıcılar, puana göre sıralanır.
  Future<List<UserModel>> getLeaderboardInCoastalBox({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 50,
  }) async {
    try {
      final response = await _db
          .from('fishing_spots')
          .select('user_id')
          .gte('lat', minLat)
          .lte('lat', maxLat)
          .gte('lng', minLng)
          .lte('lng', maxLng)
          .limit(4000);
      final ids = <String>{};
      for (final row in response as List) {
        final uid = row['user_id'] as String?;
        if (uid != null && uid.isNotEmpty) ids.add(uid);
      }
      if (ids.isEmpty) return [];
      var users = await getProfilesByIds(ids.toList());
      users.sort((a, b) => b.totalScore.compareTo(a.totalScore));
      if (users.length > limit) {
        users = users.take(limit).toList();
      }
      return users;
    } on PostgrestException catch (e) {
      throw Exception('Bölgesel sıralama alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Bölgesel sıralama alınamadı: $e');
    }
  }

  /// Son 7 gündeki check-in sayısına göre haftalık sıralama.
  ///
  /// Checkins tablosundan son 7 günün aktivitesi kullanılır;
  /// `total_score` yerine haftalık etkinlik metriği gösterilir.
  Future<List<WeeklyRankEntry>> getWeeklyLeaderboard({int limit = 50}) async {
    try {
      final dynamic raw = await _db.rpc(
        'weekly_leaderboard',
        params: {'limit_count': limit},
      );
      if (raw is List && raw.isNotEmpty) {
        try {
          return raw
              .map((row) {
                final m = row as Map<String, dynamic>;
                final uid = m['user_id'] as String;
                final name = UserModel.displayUsername(
                  rawUsername: m['username'] as String?,
                  userId: uid,
                );
                return WeeklyRankEntry(
                  userId: uid,
                  username: name,
                  avatarUrl: m['avatar_url'] as String?,
                  rank: m['rank'] as String? ?? 'acemi',
                  checkinCount: UserModel.coerceToInt(m['checkin_count']),
                );
              })
              .toList();
        } catch (_) {}
      }
    } on PostgrestException catch (_) {}

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
        final name = UserModel.displayUsername(
          rawUsername: meta['username'] as String?,
          userId: e.key,
        );
        return WeeklyRankEntry(
          userId: e.key,
          username: name,
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

  /// Kullanıcı adına göre arama (büyük/küçük harf duyarsız). En az 2 karakter.
  Future<List<UserModel>> searchUsersByUsername({
    required String query,
    int limit = 25,
  }) async {
    final raw = query.trim();
    if (raw.length < 2) return [];
    final escaped = raw.replaceAll(RegExp(r'[%_]'), '');
    if (escaped.length < 2) return [];
    try {
      final pattern = '%$escaped%';
      final response = await _db
          .from('users')
          .select(
            'id, email, username, avatar_url, rank, total_score, sustainability_score, fcm_token, created_at',
          )
          .ilike('username', pattern)
          .order('total_score', ascending: false)
          .limit(limit);
      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Arama yapılırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Arama yapılamadı: $e');
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
