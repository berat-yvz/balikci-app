import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/score_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/post_model.dart';

/// [post_comments] tablosu — SupabaseService üzerinden erişim.
class CommentRepository {
  final _remote = SupabaseService.client;

  String? get _uid => SupabaseService.auth.currentUser?.id;

  static const _commentSelect =
      'id, post_id, user_id, content, created_at, user:users(username, avatar_url, email)';

  void _scoreEvent(
    String userId,
    ScoreSource source, {
    String? sourceId,
    String? postId,
  }) {
    unawaited(
      Future(() async {
        try {
          final body = <String, dynamic>{
            'source_type': source.value,
            'user_id': userId,
            'source_id': ?sourceId,
            'post_id': ?postId,
          };
          await _remote.functions.invoke('score-calculator', body: body);
        } catch (e) {
          debugPrint('score-calculator çağrı hatası (${source.value}): $e');
        }
      }),
    );
  }

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

  /// Yeni yorum ekler (skor + bildirim yan etkileri [PostRepository] ile aynı).
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

  /// Oturum kullanıcısının kendi yorumunu siler (RLS ile uyumlu).
  Future<void> deleteComment(String commentId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Silme için giriş yapmalısın.');
    try {
      final rows = await _remote
          .from('post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', uid)
          .select('id');
      final list = rows as List<dynamic>? ?? const [];
      if (list.isEmpty) {
        throw Exception('Yorum silinemedi veya yetkin yok.');
      }
    } on PostgrestException catch (e) {
      debugPrint('deleteComment hatası: ${e.message}');
      rethrow;
    }
  }
}
