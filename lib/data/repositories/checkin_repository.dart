import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// cleaned: public method dokümantasyonu ve eksik hata yönetimi standardize edildi

/// Check-in repository — checkins + checkin_votes CRUD.
/// H5 ve H6 sprint görevleri.
class CheckinRepository {
  final _db = SupabaseService.client;

  /// Belirli meradaki aktif check-in kayıtlarını döner.
  Future<List<CheckinModel>> getActiveCheckins(String spotId) async {
    try {
      final response = await _db
          .from('checkins')
          .select()
          .eq('spot_id', spotId)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return response.map<CheckinModel>(CheckinModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception('Aktif check-in kayıtları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Aktif check-in kayıtları alınamadı: $e');
    }
  }

  /// H5 (Map UI) için: Realtime olmadan global aktif check-in'leri tek çağrıyla çek.
  /// Sonra Map içindeki visible meralarla eşleştirilir.
  Future<List<CheckinModel>> getActiveCheckinsAll({int limit = 2000}) async {
    try {
      final response = await _db
          .from('checkins')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(0, limit - 1);

      return response.map<CheckinModel>(CheckinModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception('Aktif check-in listesi alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Aktif check-in listesi alınamadı: $e');
    }
  }

  /// H5 (Map UI) için: Son N saat içindeki check-in'leri çek.
  ///
  /// - 2 saatten eski olanlar UI'da "soluk"
  /// - 6 saatten eski olanlar UI'dan kalkar
  Future<List<CheckinModel>> getRecentCheckinsAll({
    int limit = 2000,
    int hours = AppConstants.checkinRemoveHours,
  }) async {
    try {
      final threshold = DateTime.now().subtract(Duration(hours: hours));

      final response = await _db
          .from('checkins')
          .select()
          .gte('created_at', threshold.toIso8601String())
          .order('created_at', ascending: false)
          .range(0, limit - 1);

      return response.map<CheckinModel>(CheckinModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception('Son check-in kayıtları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Son check-in kayıtları alınamadı: $e');
    }
  }

  /// Yeni bir check-in kaydı oluşturur.
  Future<CheckinModel?> addCheckin(Map<String, dynamic> data) async {
    try {
      final response = await _db
          .from('checkins')
          .insert(data)
          .select()
          .single();
      return CheckinModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Check-in oluşturulamadı: ${e.message}');
    } catch (e) {
      throw Exception('Check-in oluşturulamadı: $e');
    }
  }

  /// checkins.photo_url güncellemesi.
  ///
  /// EXIF doğrulama Edge Function'ı bu photo_url / dosya yolu üzerinden
  /// checkin'i eşleyebilir (MVP akışı için photo path yeterli).
  Future<void> updateCheckinPhotoUrl({
    required String checkinId,
    required String photoUrl,
  }) async {
    try {
      await _db
          .from('checkins')
          .update({'photo_url': photoUrl})
          .eq('id', checkinId);
    } on PostgrestException catch (e) {
      throw Exception('Check-in fotoğrafı güncellenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Check-in fotoğrafı güncellenemedi: $e');
    }
  }

  /// Belirli mera için son 6 saatlik check-in kayıtlarını kullanıcı adıyla döner.
  Future<List<CheckinModel>> getCheckinsForSpot(String spotId) async {
    try {
      final threshold = DateTime.now().subtract(
        const Duration(hours: AppConstants.checkinRemoveHours),
      );
      final response = await _db
          .from('checkins')
          .select('*, users:user_id(username)')
          .eq('spot_id', spotId)
          .gte('created_at', threshold.toIso8601String())
          .order('created_at', ascending: false);
      final baseItems = response
          .map<CheckinModel>(CheckinModel.fromJson)
          .toList();
      final voteCountsList = await Future.wait(
        baseItems.map((c) => getVoteCounts(c.id)),
      );

      final withVotes = <CheckinModel>[];
      for (var i = 0; i < baseItems.length; i++) {
        final base = baseItems[i];
        final counts = voteCountsList[i];
        final trueVotes = counts[true] ?? 0;
        final falseVotes = counts[false] ?? 0;
        final model = CheckinModel(
          id: base.id,
          userId: base.userId,
          spotId: base.spotId,
          username: base.username,
          crowdLevel: base.crowdLevel,
          fishDensity: base.fishDensity,
          photoUrl: base.photoUrl,
          exifVerified: base.exifVerified,
          isActive: base.isActive,
          trueVotes: trueVotes,
          falseVotes: falseVotes,
          createdAt: base.createdAt,
        );
        final total = trueVotes + falseVotes;
        final falseRatio = total == 0 ? 0.0 : (falseVotes / total);
        final shouldHide = total >= 3 && falseRatio > 0.70;
        if (!shouldHide) {
          withVotes.add(model);
        }
      }
      return withVotes;
    } on PostgrestException catch (e) {
      throw Exception('Mera check-in kayıtları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Mera check-in kayıtları alınamadı: $e');
    }
  }

  /// Kullanıcının ilgili check-in için verdiği oyu döner (`null` ise oy yok).
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
  /// Kullanıcının oyunu toggle davranışıyla günceller.
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

  /// %70+ yanlış oy geldiğinde check-in'i gizle.
  /// is_active = false yaparak haritadan ve listelerden kaldırır.
  /// RLS: sadece service_role veya check-in sahibi update yapabilir.
  /// MVP'de bu çağrıyı client-side score-calculator yerine yaparız.
  Future<void> hideCheckin(String checkinId) async {
    await _db
        .from('checkins')
        .update({'is_active': false})
        .eq('id', checkinId);
  }

  /// Oy sayılarını hesapla; eşik aşıldıysa check-in'i gizle.
  /// Dönüş: true → gizlendi, false → henüz eşik aşılmadı
  Future<bool> evaluateAndHide(String checkinId) async {
    final counts = await getVoteCounts(checkinId);
    final falseCount = counts[false] ?? 0;
    final total = (counts[true] ?? 0) + falseCount;

    if (total < 3) return false; // minimum 3 oy şartı

    final ratio = falseCount / total;
    if (ratio >= AppConstants.voteThresholdPercent) {
      await hideCheckin(checkinId);
      return true;
    }
    return false;
  }

  /// Oylama istatistiği — score-calculator Edge Function'ı da bunu kullanır
  Future<Map<bool, int>> getVoteCounts(String checkinId) async {
    try {
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
    } on PostgrestException catch (e) {
      throw Exception('Oy sayıları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Oy sayıları alınamadı: $e');
    }
  }
}
