import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/checkin_model.dart';

/// Check-in repository — checkins + checkin_votes CRUD.
/// H5 ve H6 sprint görevleri.
class CheckinRepository {
  final _db = SupabaseService.client;

  Future<List<CheckinModel>> getActiveCheckins(String spotId) async {
    final response = await _db
        .from('checkins')
        .select()
        .eq('spot_id', spotId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return response.map<CheckinModel>(CheckinModel.fromJson).toList();
  }

  Future<CheckinModel?> addCheckin(Map<String, dynamic> data) async {
    final response =
        await _db.from('checkins').insert(data).select().single();
    return CheckinModel.fromJson(response);
  }

  /// Oylama: vote = true → doğru, false → yanlış
  Future<void> vote({
    required String checkinId,
    required String voterId,
    required bool vote,
  }) async {
    await _db.from('checkin_votes').upsert({
      'checkin_id': checkinId,
      'voter_id': voterId,
      'vote': vote,
    });
  }

  /// Oylama istatistiği — score-calculator Edge Function'ı da bunu kullanır
  Future<Map<String, int>> getVoteCounts(String checkinId) async {
    final response = await _db
        .from('checkin_votes')
        .select('vote')
        .eq('checkin_id', checkinId);
    int trueCount = 0, falseCount = 0;
    for (final row in response) {
      if (row['vote'] == true) trueCount++;
      else falseCount++;
    }
    return {'true': trueCount, 'false': falseCount};
  }
}
