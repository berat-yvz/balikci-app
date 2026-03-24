import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:drift/drift.dart';

/// Mera repository — fishing_spots CRUD.
/// H3 ve H4 sprint görevleri.
class SpotRepository {
  final _db = SupabaseService.client;
  final _localDb = AppDatabase.instance;

  Future<List<SpotModel>> getSpots({
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await _db
        .from('fishing_spots')
        .select()
        .range(offset, offset + limit - 1);
    final remote = response.map<SpotModel>(SpotModel.fromJson).toList();
    await _cacheSpots(remote);
    return remote;
  }

  Future<List<SpotModel>> getSpotsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
    int offset = 0,
  }) async {
    final response = await _db
        .from('fishing_spots')
        .select()
        .gte('lat', minLat)
        .lte('lat', maxLat)
        .gte('lng', minLng)
        .lte('lng', maxLng)
        .range(offset, offset + limit - 1);
    final remote = response.map<SpotModel>(SpotModel.fromJson).toList();
    await _cacheSpots(remote);
    return remote;
  }

  Future<SpotModel?> getSpotById(String id) async {
    try {
      final data =
          await _db.from('fishing_spots').select().eq('id', id).single();
      return SpotModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<SpotModel?> addSpot(Map<String, dynamic> spotData) async {
    final response = await _db
        .from('fishing_spots')
        .insert(spotData)
        .select()
        .single();
    final created = SpotModel.fromJson(response);
    await _cacheSpots([created]);
    return created;
  }

  Future<void> updateSpot(String id, Map<String, dynamic> updates) async {
    await _db.from('fishing_spots').update(updates).eq('id', id);
    final fresh = await getSpotById(id);
    if (fresh != null) {
      await _cacheSpots([fresh]);
    }
  }

  Future<void> deleteSpot(String id) async {
    await _db.from('fishing_spots').delete().eq('id', id);
    await (_localDb.delete(_localDb.localSpots)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

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
