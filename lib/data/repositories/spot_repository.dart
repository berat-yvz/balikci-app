import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// cleaned: hata yönetimi, method dokümantasyonu ve public API açıklamaları iyileştirildi

/// Mera repository — fishing_spots CRUD.
/// H3 ve H4 sprint görevleri.
class SpotRepository {
  final _db = SupabaseService.client;
  final _localDb = AppDatabase.instance;

  /// Tüm meraları uzak kaynaktan çeker ve local cache'e yazar.
  Future<List<SpotModel>> getSpots({int limit = 500, int offset = 0}) async {
    try {
      final response = await _db
          .from('fishing_spots')
          .select('id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at')
          .range(offset, offset + limit - 1);
      final remote = response.map<SpotModel>(SpotModel.fromJson).toList();
      await _cacheSpots(remote);
      return remote;
    } on PostgrestException catch (e) {
      throw Exception('Meralar alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Meralar alınamadı: $e');
    }
  }

  /// Verilen koordinat sınırları içindeki meraları döner.
  Future<List<SpotModel>> getSpotsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final response = await _db
          .from('fishing_spots')
          .select('id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at')
          .gte('lat', minLat)
          .lte('lat', maxLat)
          .gte('lng', minLng)
          .lte('lng', maxLng)
          .range(offset, offset + limit - 1);
      final remote = response.map<SpotModel>(SpotModel.fromJson).toList();
      await _cacheSpots(remote);
      return remote;
    } on PostgrestException catch (e) {
      throw Exception('Sınır içi meralar alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Sınır içi meralar alınamadı: $e');
    }
  }

  /// Belirli kullanıcının eklediği meralar (yeniden eskiye).
  Future<List<SpotModel>> getSpotsByUserId(
    String userId, {
    int limit = 200,
  }) async {
    try {
      final response = await _db
          .from('fishing_spots')
          .select(
            'id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map<SpotModel>(
            (row) => SpotModel.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Kullanıcı meraları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Kullanıcı meraları alınamadı: $e');
    }
  }

  /// ID ile tek bir mera kaydı döner, bulunamazsa `null` verir.
  Future<SpotModel?> getSpotById(String id) async {
    try {
      final data = await _db
          .from('fishing_spots')
          .select('id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at')
          .eq('id', id)
          .single();
      return SpotModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Yeni mera kaydı oluşturur ve cache'i günceller.
  Future<SpotModel?> addSpot(Map<String, dynamic> spotData) async {
    try {
      final response = await _db
          .from('fishing_spots')
          .insert(spotData)
          .select('id, user_id, name, lat, lng, type, privacy_level, description, verified, muhtar_id, created_at')
          .single();
      final created = SpotModel.fromJson(response);
      await _cacheSpots([created]);
      return created;
    } on PostgrestException catch (e) {
      throw Exception('Mera eklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Mera eklenemedi: $e');
    }
  }

  /// Mevcut mera kaydını günceller ve cache'i tazeler.
  /// Yalnızca `user_id` oturumdaki kullanıcı ile eşleşen satır güncellenir.
  Future<void> updateSpot(String id, Map<String, dynamic> updates) async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Mera güncellemek için giriş yapmalısın.');
    }
    try {
      final row = await _db
          .from('fishing_spots')
          .update(updates)
          .eq('id', id)
          .eq('user_id', uid)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw Exception(
          'Bu merayı yalnızca ekleyen kullanıcı düzenleyebilir.',
        );
      }
      final fresh = await getSpotById(id);
      if (fresh != null) {
        await _cacheSpots([fresh]);
      }
    } on PostgrestException catch (e) {
      throw Exception('Mera güncellenemedi: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Mera güncellenemedi: $e');
    }
  }

  /// Mera kaydını uzak ve yerel depodan siler.
  /// Yalnızca `user_id` oturumdaki kullanıcı ile eşleşen satır silinir.
  Future<void> deleteSpot(String id) async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Mera silmek için giriş yapmalısın.');
    }
    try {
      final removed = await _db
          .from('fishing_spots')
          .delete()
          .eq('id', id)
          .eq('user_id', uid)
          .select('id');
      if ((removed as List).isEmpty) {
        throw Exception(
          'Bu merayı yalnızca ekleyen kullanıcı silebilir.',
        );
      }
      await (_localDb.delete(
        _localDb.localSpots,
      )..where((tbl) => tbl.id.equals(id))).go();
    } on PostgrestException catch (e) {
      throw Exception('Mera silinemedi: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Mera silinemedi: $e');
    }
  }

  /// Yerel cache'deki mera kayıtlarını döner.
  Future<List<SpotModel>> getCachedSpots() async {
    final rows = await _localDb.select(_localDb.localSpots).get();
    return rows
        .map(
          (r) => SpotModel(
            id: r.id,
            userId: r.userId,
            name: r.name,
            lat: r.lat,
            lng: r.lng,
            type: r.type,
            privacyLevel: r.privacyLevel,
            description: r.description,
            verified: r.verified,
            muhtarId: r.muhtarId,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  /// Uzak kaynaktan gelen mera listesini local cache'e yazar.
  Future<void> _cacheSpots(List<SpotModel> spots) async {
    if (spots.isEmpty) return;
    await _localDb.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _localDb.localSpots,
        spots
            .map(
              (spot) => LocalSpotsCompanion.insert(
                id: spot.id,
                userId: spot.userId,
                name: spot.name,
                lat: spot.lat,
                lng: spot.lng,
                type: Value(spot.type),
                privacyLevel: spot.privacyLevel,
                description: Value(spot.description),
                verified: Value(spot.verified),
                muhtarId: Value(spot.muhtarId),
                createdAt: spot.createdAt,
              ),
            )
            .toList(),
      );
    });
  }
}
