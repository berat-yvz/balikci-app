import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/user_model.dart';

/// Kullanıcı profili repository.
class UserRepository {
  final _db = SupabaseService.client;

  Future<UserModel?> getUserById(String id) async {
    try {
      final data = await _db.from('users').select().eq('id', id).single();
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(String id, Map<String, dynamic> updates) async {
    await _db.from('users').update(updates).eq('id', id);
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _db
        .from('users')
        .update({'fcm_token': token}).eq('id', userId);
  }

  /// Lider tablosu — toplam puana göre sıralı
  Future<List<UserModel>> getLeaderboard({int limit = 50}) async {
    final response = await _db
        .from('users')
        .select()
        .order('total_score', ascending: false)
        .limit(limit);
    return response.map<UserModel>(UserModel.fromJson).toList();
  }
}
