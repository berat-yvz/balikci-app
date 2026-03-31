import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// H5 (Map UI) için: Realtime olmadan global aktif check-in'leri tek çağrıyla çek.
  /// Sonra Map içindeki visible meralarla eşleştirilir.
  Future<List<CheckinModel>> getActiveCheckinsAll({int limit = 2000}) async {
    final response = await _db
        .from('checkins')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .range(0, limit - 1);

    return response.map<CheckinModel>(CheckinModel.fromJson).toList();
  }

  /// H5 (Map UI) için: Son N saat içindeki check-in'leri çek.
  ///
  /// - 2 saatten eski olanlar UI'da "soluk"
  /// - 6 saatten eski olanlar UI'dan kalkar
  Future<List<CheckinModel>> getRecentCheckinsAll({
    int limit = 2000,
    int hours = AppConstants.checkinRemoveHours,
  }) async {
    final threshold = DateTime.now().subtract(Duration(hours: hours));

    final response = await _db
        .from('checkins')
        .select()
        .gte('created_at', threshold.toIso8601String())
        .order('created_at', ascending: false)
        .range(0, limit - 1);

    return response.map<CheckinModel>(CheckinModel.fromJson).toList();
  }

  Future<CheckinModel?> addCheckin(Map<String, dynamic> data) async {
    final response =
        await _db.from('checkins').insert(data).select().single();
    return CheckinModel.fromJson(response);
  }

  /// checkins.photo_url güncellemesi.
  ///
  /// EXIF doğrulama Edge Function'ı bu photo_url / dosya yolu üzerinden
  /// checkin'i eşleyebilir (MVP akışı için photo path yeterli).
  Future<void> updateCheckinPhotoUrl({
    required String checkinId,
    required String photoUrl,
  }) async {
    await _db
        .from('checkins')
        .update({'photo_url': photoUrl})
        .eq('id', checkinId);
  }

  Future<List<CheckinModel>> getCheckinsForSpot(String spotId) async {
    final threshold = DateTime.now().subtract(
      const Duration(hours: AppConstants.checkinRemoveHours),
    );
    final response = await _db
        .from('checkins')
        .select('*, users:user_id(username)')
        .eq('spot_id', spotId)
        .gte('created_at', threshold.toIso8601String())
        .order('created_at', ascending: false);
    return response.map<CheckinModel>(CheckinModel.fromJson).toList();
  }

  Future<bool?> getUserVote(String checkinId, String userId) async {
    try {
      final response = await _db
          .from('checkin_votes')
          .select('vote')
          .eq('checkin_id', checkinId)
          .eq('voter_id', userId)
          .maybeSingle();
      return response?['vote'] as bool?;
    } on PostgrestException catch (e) {
      throw Exception('Kullanıcı oyu okunamadı: ${e.message}');
    } catch (e) {
      throw Exception('Kullanıcı oyu okunamadı: $e');
    }
  }

  /// Oylama: voteValue = true → doğru, false → yanlış
  /// Toggle davranışı:
  /// - Aynı oy: kaldır
  /// - Farklı oy: eskiyi kaldır, yeniyi ekle
  /// - Oy yoksa: yeni oy ekle
  Future<void> castVote({
    required String checkinId,
    required String voterId,
    required bool voteValue,
  }) async {
    try {
      final existing = await getUserVote(checkinId, voterId);
      if (existing == voteValue) {
        await unvote(checkinId: checkinId, voterId: voterId);
        return;
      }

      await unvote(checkinId: checkinId, voterId: voterId);
      await _db.from('checkin_votes').insert({
            'checkin_id': checkinId,
            'voter_id': voterId,
            'vote': voteValue,
          });
    } on PostgrestException catch (e) {
      throw Exception('Oylama gönderilemedi: ${e.message}');
    } catch (e) {
      throw Exception('Oylama gönderilemedi: $e');
    }
  }

  /// Unvote — kullanıcı oyunu geri alır.
  Future<void> unvote({
    required String checkinId,
    required String voterId,
  }) async {
    try {
      await _db
          .from('checkin_votes')
          .delete()
          .eq('checkin_id', checkinId)
          .eq('voter_id', voterId);
    } on PostgrestException catch (e) {
      throw Exception('Oylama geri alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Oylama geri alınamadı: $e');
    }
  }

  /// Oylama istatistiği — score-calculator Edge Function'ı da bunu kullanır
  Future<Map<bool, int>> getVoteCounts(String checkinId) async {
    final response = await _db
        .from('checkin_votes')
        .select('vote')
        .eq('checkin_id', checkinId);
    int trueCount = 0, falseCount = 0;
    for (final row in response) {
      if (row['vote'] == true) {
        trueCount++;
      } else {
        falseCount++;
      }
    }
    return {true: trueCount, false: falseCount};
  }
}
