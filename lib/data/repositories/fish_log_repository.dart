import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';

/// Balık günlüğü repository — offline-first mantığı H7'de Isar ile tamamlanacak.
class FishLogRepository {
  final _db = SupabaseService.client;

  Future<List<FishLogModel>> getMyLogs(String userId) async {
    final response = await _db
        .from('fish_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map<FishLogModel>(FishLogModel.fromJson).toList();
  }

  Future<FishLogModel?> addLog(Map<String, dynamic> data) async {
    final response =
        await _db.from('fish_logs').insert(data).select().single();
    return FishLogModel.fromJson(response);
  }

  Future<void> updateLog(String id, Map<String, dynamic> updates) async {
    await _db.from('fish_logs').update(updates).eq('id', id);
  }

  Future<void> deleteLog(String id) async {
    await _db.from('fish_logs').delete().eq('id', id);
  }

  /// İstatistik: kullanıcının tür bazında av sayısı
  Future<Map<String, int>> getSpeciesStats(String userId) async {
    final logs = await getMyLogs(userId);
    final stats = <String, int>{};
    for (final log in logs) {
      stats[log.species] = (stats[log.species] ?? 0) + 1;
    }
    return stats;
  }
}
