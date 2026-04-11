import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';

/// Takip (follow) repository — follows tablosu INSERT/DELETE/SELECT.
class FollowRepository {
  final SupabaseClient _db = SupabaseService.client;

  Future<void> follow(String targetUserId) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Takip işlemi için önce giriş yapmalısın.');
    }

    try {
      await _db.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      throw Exception(
        'Kullanıcı takip edilirken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Kullanıcı takip edilemedi: $e');
    }
  }

  Future<void> unfollow(String targetUserId) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Takipten çıkmak için önce giriş yapmalısın.');
    }

    try {
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId);
    } on PostgrestException catch (e) {
      throw Exception('Takipten çıkılırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Takipten çıkılamadı: $e');
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      final response = await _db
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .limit(1);
      return (response as List).isNotEmpty;
    } on PostgrestException catch (e) {
      throw Exception('Takip durumu alınırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Takip durumu alınamadı: $e');
    }
  }

  /// [otherUserId] şu anki kullanıcıyı takip ediyor mu?
  Future<bool> isFollowedBy(String otherUserId) async {
    final currentUserId = SupabaseService.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      final response = await _db
          .from('follows')
          .select('id')
          .eq('follower_id', otherUserId)
          .eq('following_id', currentUserId)
          .limit(1);
      return (response as List).isNotEmpty;
    } on PostgrestException catch (e) {
      throw Exception('Takip durumu alınırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Takip durumu alınamadı: $e');
    }
  }

  /// Karşılıklı takip (arkadaş).
  Future<bool> areMutualFriends(String otherUserId) async {
    final a = await isFollowing(otherUserId);
    if (!a) return false;
    return isFollowedBy(otherUserId);
  }

  Future<List<String>> getFollowerIds(String userId) async {
    try {
      final response = await _db
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);
      return (response as List)
          .map((row) => row['follower_id'] as String)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Takipçi listesi alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Takipçi listesi alınamadı: $e');
    }
  }

  /// Karşılıklı takip edilen kullanıcı kimlikleri (arkadaşlar).
  Future<List<String>> getMutualFriendIds(String userId) async {
    final followers = (await getFollowerIds(userId)).toSet();
    if (followers.isEmpty) return [];
    final following = await getFollowingIds(userId);
    return following.where(followers.contains).toList();
  }

  Future<List<String>> getFollowingIds(String userId) async {
    try {
      final response = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      return (response as List)
          .map((row) => row['following_id'] as String)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Takip edilenler listesi alınırken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Takip edilenler listesi alınamadı: $e');
    }
  }
}
