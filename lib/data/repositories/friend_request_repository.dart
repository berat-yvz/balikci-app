import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/friend_request_model.dart';

/// Arkadaşlık isteği — `friend_requests` tablosu.
class FriendRequestRepository {
  final SupabaseClient _db = SupabaseService.client;

  String? get _me => SupabaseService.auth.currentUser?.id;

  Future<bool> hasPendingOutgoing(String toUserId) async {
    final me = _me;
    if (me == null) return false;
    try {
      final row = await _db
          .from('friend_requests')
          .select('id')
          .eq('from_user_id', me)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      throw Exception('İstek durumu alınamadı: ${e.message}');
    }
  }

  Future<String?> getIncomingRequestId(String fromUserId) async {
    final me = _me;
    if (me == null) return null;
    try {
      final row = await _db
          .from('friend_requests')
          .select('id')
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', me)
          .eq('status', 'pending')
          .maybeSingle();
      return row?['id'] as String?;
    } on PostgrestException catch (e) {
      throw Exception('İstek bilgisi alınamadı: ${e.message}');
    }
  }

  Future<bool> hasPendingIncomingFrom(String fromUserId) async {
    final me = _me;
    if (me == null) return false;
    try {
      final row = await _db
          .from('friend_requests')
          .select('id')
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', me)
          .eq('status', 'pending')
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      throw Exception('İstek durumu alınamadı: ${e.message}');
    }
  }

  /// Gelen bekleyen istekler.
  Future<List<FriendRequestModel>> listIncomingPending() async {
    final me = _me;
    if (me == null) return [];
    try {
      final response = await _db
          .from('friend_requests')
          .select('id, from_user_id, to_user_id, status, created_at')
          .eq('to_user_id', me)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (response as List)
          .map((row) => FriendRequestModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('İstekler alınamadı: ${e.message}');
    }
  }

  Future<void> sendRequest(String toUserId) async {
    final me = _me;
    if (me == null) {
      throw Exception('Önce giriş yapmalısın.');
    }
    if (me == toUserId) return;
    try {
      await _db.from('friend_requests').upsert(
        {
          'from_user_id': me,
          'to_user_id': toUserId,
          'status': 'pending',
        },
        onConflict: 'from_user_id,to_user_id',
      );
    } on PostgrestException catch (e) {
      throw Exception('İstek gönderilemedi: ${e.message}');
    }
  }

  /// Gönderilen bekleyen isteği iptal (sil).
  Future<void> cancelOutgoing(String toUserId) async {
    final me = _me;
    if (me == null) return;
    try {
      await _db
          .from('friend_requests')
          .delete()
          .eq('from_user_id', me)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw Exception('İstek iptal edilemedi: ${e.message}');
    }
  }

  Future<void> rejectRequest(String requestId) async {
    final me = _me;
    if (me == null) return;
    try {
      await _db
          .from('friend_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId)
          .eq('to_user_id', me)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw Exception('İstek reddedilemedi: ${e.message}');
    }
  }

  /// Sunucu tarafı karşılıklı takip + isteği kabul et (`accept_friend_request` RPC).
  Future<void> acceptRequest(String requestId) async {
    if (_me == null) {
      throw Exception('Önce giriş yapmalısın.');
    }
    try {
      await _db.rpc(
        'accept_friend_request',
        params: {'request_id': requestId},
      );
    } on PostgrestException catch (e) {
      throw Exception('İstek kabul edilemedi: ${e.message}');
    }
  }
}
