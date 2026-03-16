import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';

/// Mera repository — fishing_spots CRUD.
/// H3 ve H4 sprint görevleri.
class SpotRepository {
  final _db = SupabaseService.client;

  Future<List<SpotModel>> getSpots() async {
    final response = await _db.from('fishing_spots').select();
    return response.map<SpotModel>(SpotModel.fromJson).toList();
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
    return SpotModel.fromJson(response);
  }

  Future<void> updateSpot(String id, Map<String, dynamic> updates) async {
    await _db.from('fishing_spots').update(updates).eq('id', id);
  }

  Future<void> deleteSpot(String id) async {
    await _db.from('fishing_spots').delete().eq('id', id);
  }
}
