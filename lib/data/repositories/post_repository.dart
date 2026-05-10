import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/post_model.dart';

/// Sosyal akış repository — posts, post_likes, post_comments tabloları.
///
/// Tüm okuma sorguları Supabase RLS ile korunur; private/vip gönderiler
/// yetkisiz kullanıcılara dönmez.
class PostRepository {
  final _remote = SupabaseService.client;

  String? get _uid => SupabaseService.auth.currentUser?.id;

  // ─── PostgREST select sabitleri ────────────────────────────────────────────

  /// Posts için tam select — author ve spot join'leri dahil.
  static const _postSelect = '''
    id, user_id, photo_url, caption, fish_species,
    spot_id, spot_privacy_snapshot, spot_district,
    likes_count, comments_count,
    is_deleted, created_at,
    author:users(username, avatar_url, rank, email),
    spot:fishing_spots(name)
  ''';

  /// Comments için tam select — user join dahil.
  static const _commentSelect =
      'id, post_id, user_id, content, created_at, user:users(username, avatar_url, email)';

  // ─── Yardımcı: puan hesapla (fire-and-forget) ──────────────────────────────

  void _scoreEvent(
    String userId,
    ScoreSource source, {
    String? sourceId,
    String? spotId,
    String? postId,
    String? likerId,
  }) {
    unawaited(
      Future(() async {
        try {
          final body = <String, dynamic>{
            'source_type': source.value,
            'user_id': userId,
            'source_id': ?sourceId,
            'spot_id': ?spotId,
            'post_id': ?postId,
            'liker_id': ?likerId,
          };
          await _remote.functions.invoke(
            'score-calculator',
            body: body,
          );
        } catch (e) {
          debugPrint('score-calculator çağrı hatası (${source.value}): $e');
        }
      }),
    );
  }

  Future<void> _shadowPointEvent({
    required String postId,
    required String posterUserId,
    String? spotId,
  }) async {
    try {
      await _remote.functions.invoke(
        'shadow-point-calculator',
        body: {
          'post_id': postId,
          'poster_user_id': posterUserId,
          'spot_id': spotId,
        },
      );
    } catch (e, st) {
      debugPrint('_shadowPointEvent hata: $e\n$st');
    }
  }

  // ─── Yardımcı: bildirim gönder (fire-and-forget) ───────────────────────────

  /// [actorId] ile [postOwnerId] aynıysa bildirim gönderilmez (öz-bildirim önleme).
  void _notifyPostActivity({
    required String postOwnerId,
    required String actorId,
    required String type,
    required String title,
    required String body,
    required String postId,
  }) {
    if (actorId == postOwnerId) return;
    unawaited(
      Future(() async {
        try {
          await _remote.functions.invoke(
            'notification-sender',
            body: {
              'user_id': postOwnerId,
              'actor_id': actorId,
              'title': title,
              'body': body,
              'data': {'type': type, 'post_id': postId},
            },
          );
        } catch (e) {
          debugPrint('notification-sender çağrı hatası ($type): $e');
        }
      }),
    );
  }

  // ─── Gönderi oluştur ───────────────────────────────────────────────────────

  /// Yeni post ekler ve oluşturulan [PostModel]'i döner.
  ///
  /// [spotId] verilmişse mera gizlilik seviyesi önce Supabase'den çekilir;
  /// mera bulunamazsa 'public' varsayılanı kullanılır.
  Future<PostModel> createPost({
    required String photoUrl,
    String? caption,
    List<String>? fishSpecies,
    String? spotId,
    String? spotDistrict,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Gönderi oluşturmak için giriş yapmalısın.');

    // Mera gizlilik seviyesi snapshot'ı
    var spotPrivacySnapshot = 'public';
    if (spotId != null) {
      try {
        final spot = await _remote
            .from('fishing_spots')
            .select('privacy_level')
            .eq('id', spotId)
            .maybeSingle();
        if (spot != null) {
          spotPrivacySnapshot = spot['privacy_level'] as String? ?? 'public';
        }
      } catch (e) {
        debugPrint('Mera gizlilik seviyesi alınamadı (public varsayıldı): $e');
      }
    }

    try {
      final response = await _remote
          .from('posts')
          .insert({
            'user_id': uid,
            'photo_url': photoUrl,
            'caption': caption,
            'fish_species': fishSpecies,
            'spot_id': spotId,
            'spot_privacy_snapshot': spotPrivacySnapshot,
            'spot_district': spotDistrict,
          })
          .select(_postSelect)
          .single();

      final post = PostModel.fromJson(response);
      _scoreEvent(uid, ScoreSource.postShared, sourceId: post.id);
      unawaited(
        _shadowPointEvent(
          postId: post.id,
          posterUserId: uid,
          spotId: post.spotId,
        ),
      );
      return post;
    } on PostgrestException catch (e) {
      debugPrint('createPost hatası: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('createPost hatası: $e');
      rethrow;
    }
  }

  // ─── Arkadaşlar akışı ─────────────────────────────────────────────────────

  /// Takip edilen kullanıcıların public ve friends görünürlüklü gönderileri.
  /// Cursor-based pagination: [cursor] verilirse o tarihten öncesi döner.
  Future<List<PostModel>> getFriendsFeed({
    int limit = 20,
    DateTime? cursor,
  }) async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      // Takip edilen kullanıcı ID'lerini al
      final followRows = await _remote
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);

      final followingIds = (followRows as List)
          .map((r) => r['following_id'] as String)
          .toList();

      if (followingIds.isEmpty) return [];

      final List<Map<String, dynamic>> response;
      if (cursor != null) {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .inFilter('user_id', followingIds)
            .eq('is_deleted', false)
            .inFilter('spot_privacy_snapshot', ['public', 'friends'])
            .lt('created_at', cursor.toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .inFilter('user_id', followingIds)
            .eq('is_deleted', false)
            .inFilter('spot_privacy_snapshot', ['public', 'friends'])
            .order('created_at', ascending: false)
            .limit(limit);
      }

      return response.map(PostModel.fromJson).toList();
    } on PostgrestException catch (e) {
      debugPrint('PostRepository hata (posts tablosu yok olabilir): ${e.message}');
      return [];
    } catch (e, st) {
      debugPrint('PostRepository beklenmedik hata (getFriendsFeed): $e\n$st');
      return [];
    }
  }

  // ─── Türkiye akışı ────────────────────────────────────────────────────────

  /// Tüm kullanıcıların public gönderileri — "Türkiye" sekmesi.
  Future<List<PostModel>> getGlobalFeed({
    int limit = 20,
    DateTime? cursor,
  }) async {
    try {
      final List<Map<String, dynamic>> response;
      if (cursor != null) {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .eq('is_deleted', false)
            .eq('spot_privacy_snapshot', 'public')
            .lt('created_at', cursor.toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .eq('is_deleted', false)
            .eq('spot_privacy_snapshot', 'public')
            .order('created_at', ascending: false)
            .limit(limit);
      }

      return response.map(PostModel.fromJson).toList();
    } on PostgrestException catch (e) {
      debugPrint('PostRepository hata (posts tablosu yok olabilir): ${e.message}');
      return [];
    } catch (e, st) {
      debugPrint('PostRepository beklenmedik hata (getGlobalFeed): $e\n$st');
      return [];
    }
  }

  // ─── Kullanıcı gönderileri ─────────────────────────────────────────────────

  /// Belirtilen kullanıcının gönderileri — profil ekranı grid'i için.
  /// RLS; kendi gönderileri (private/vip dahil) vs. başkasının
  /// public/friends gönderilerini otomatik filtreler.
  Future<List<PostModel>> getPostsByUser(
    String userId, {
    int limit = 30,
    DateTime? cursor,
  }) async {
    try {
      final List<Map<String, dynamic>> response;
      if (cursor != null) {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .lt('created_at', cursor.toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      } else {
        response = await _remote
            .from('posts')
            .select(_postSelect)
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            .limit(limit);
      }

      return response.map(PostModel.fromJson).toList();
    } catch (e, st) {
      debugPrint('getPostsByUser hatası: $e\n$st');
      return [];
    }
  }

  // ─── Beğeni ───────────────────────────────────────────────────────────────

  /// Beğeni durumunu tersine çevirir.
  ///
  /// Race-condition güvenli: önce INSERT dener; unique constraint ihlali
  /// (kod 23505) gelirse zaten beğenilmiş demektir → DELETE yapar.
  ///
  /// [postOwnerId] ve [actorUsername] verilirse beğeni bildirimi gönderilir;
  /// öz-bildirim otomatik engellenir.
  Future<bool> toggleLike(
    String postId, {
    String? postOwnerId,
    String? actorUsername,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Beğeni için giriş yapmalısın.');

    try {
      await _remote.from('post_likes').insert({
        'post_id': postId,
        'user_id': uid,
      });
      // INSERT başarılı → gönderi sahibine puan (10'un katı + öz-beğeni edge'de)
      var ownerId = postOwnerId;
      if (ownerId == null) {
        final row = await _remote
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .maybeSingle();
        ownerId = row?['user_id'] as String?;
      }
      if (ownerId != null && ownerId != uid) {
        _scoreEvent(
          ownerId,
          ScoreSource.postLiked,
          postId: postId,
          likerId: uid,
        );
      }
      final notifyOwner = postOwnerId ?? ownerId;
      if (notifyOwner != null) {
        _notifyPostActivity(
          postOwnerId: notifyOwner,
          actorId: uid,
          type: 'post_like',
          title: '❤️ Yeni Beğeni',
          body: '${actorUsername ?? "Birisi"} gönderini beğendi ❤️',
          postId: postId,
        );
      }
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Zaten beğenilmiş → beğeniyi kaldır
        await _remote
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
        return false;
      }
      debugPrint('toggleLike hatası: ${e.message}');
      rethrow;
    }
  }

  /// Giriş yapmış kullanıcının belirtilen postu beğenip beğenmediğini döner.
  Future<bool> isLikedByMe(String postId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final rows = await _remote
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Yorumlar ─────────────────────────────────────────────────────────────

  /// Bir gönderinin yorumlarını tarih sırasıyla (ASC) döner.
  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final response = await _remote
          .from('post_comments')
          .select(_commentSelect)
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((r) => CommentModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('getComments hatası: $e\n$st');
      return [];
    }
  }

  /// Yeni yorum ekler ve [CommentModel] döner.
  ///
  /// [postOwnerId] verilirse yorum bildirimi gönderilir.
  Future<CommentModel> addComment({
    required String postId,
    required String content,
    String? postOwnerId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Yorum için giriş yapmalısın.');

    try {
      final response = await _remote
          .from('post_comments')
          .insert({'post_id': postId, 'user_id': uid, 'content': content})
          .select(_commentSelect)
          .single();

      final comment = CommentModel.fromJson(response);
      _scoreEvent(
        uid,
        ScoreSource.postComment,
        sourceId: comment.id,
        postId: postId,
      );

      if (postOwnerId != null && postOwnerId != uid) {
        _notifyPostActivity(
          postOwnerId: postOwnerId,
          actorId: uid,
          type: 'post_comment',
          title: '💬 Yeni Yorum',
          body: '${comment.username ?? "Birisi"} gönderine yorum yaptı 💬',
          postId: postId,
        );
      }

      return comment;
    } on PostgrestException catch (e) {
      debugPrint('addComment hatası: ${e.message}');
      rethrow;
    }
  }

  // ─── Soft delete ──────────────────────────────────────────────────────────

  /// Postu soft delete yapar (is_deleted = true).
  /// Sadece gönderi sahibi (user_id = auth.uid()) silebilir;
  /// RLS bu kuralı zorlar, ayrıca istemci tarafında da doğrulanır.
  Future<void> deletePost(String postId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Silme işlemi için giriş yapmalısın.');

    try {
      final rows = await _remote
          .from('posts')
          .update({'is_deleted': true})
          .eq('id', postId)
          .eq('user_id', uid)
          .select('id');
      final list = rows as List<dynamic>? ?? const [];
      if (list.isEmpty) {
        throw Exception(
          'Gönderi silinemedi. Bağlantını kontrol et veya sayfayı yenile.',
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('deletePost hatası: ${e.message}');
      rethrow;
    }
  }
}
