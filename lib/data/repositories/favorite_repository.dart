import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';

/// Mera favorileme repository — spot_favorites tablosu.
class FavoriteRepository {
  final _db = SupabaseService.client;

  String? get _uid => SupabaseService.auth.currentUser?.id;

  /// Giriş yapmış kullanıcının belirtilen merayı favorilerine ekleyip
  /// eklemediğini döner.
  Future<bool> isFavorited(String spotId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final rows = await _db
          .from('spot_favorites')
          .select('spot_id')
          .eq('user_id', uid)
          .eq('spot_id', spotId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Favori durumunu tersine çevirir.
  /// Mevcut durumu gözetmeksizin işlem yapar; yeni durumu (true=eklendi) döner.
  Future<bool> toggleFavorite(String spotId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Favori işlemi için giriş yapmalısın.');

    final already = await isFavorited(spotId);
    if (already) {
      await _db
          .from('spot_favorites')
          .delete()
          .eq('user_id', uid)
          .eq('spot_id', spotId);
      return false;
    } else {
      await _db.from('spot_favorites').insert({
        'user_id': uid,
        'spot_id': spotId,
      });
      return true;
    }
  }

  /// Giriş yapmış kullanıcının favori meralarını SpotModel listesi olarak döner.
  Future<List<SpotModel>> getFavoriteSpots() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _db
          .from('spot_favorites')
          .select('fishing_spots(id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final result = <SpotModel>[];
      for (final row in rows as List) {
        final spotJson = row['fishing_spots'];
        if (spotJson != null) {
          result.add(SpotModel.fromJson(spotJson as Map<String, dynamic>));
        }
      }
      return result;
    } on PostgrestException catch (e) {
      throw Exception('Favori meralar alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Favori meralar alınamadı: $e');
    }
  }

  /// Belirtilen merayı favorilemiş kullanıcıların id listesini döner.
  /// Check-in bildirimlerinde kullanılır.
  Future<List<String>> getUsersWhoFavorited(String spotId) async {
    try {
      final rows = await _db
          .from('spot_favorites')
          .select('user_id')
          .eq('spot_id', spotId);
      return (rows as List)
          .map((r) => r['user_id'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
