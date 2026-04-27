import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/constants/app_constants.dart';
import 'package:balikci_app/data/models/checkin_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// cleaned: oylama upsert, sayaç kolonları, evaluateAndHide + görünürlük bayrağı

/// Check-in repository — checkins + checkin_votes CRUD.
/// H5 ve H6 sprint görevleri.
class CheckinRepository {
  final _db = SupabaseService.client;

  /// Harita için: Son N saat içindeki check-in'leri çek.
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
          .select(
            'id, user_id, spot_id, crowd_level, fish_density, fish_species, photo_url, exif_verified, is_hidden, true_votes, false_votes, created_at, expires_at',
          )
          .eq('is_hidden', false)
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

  /// Aktif, gizlenmemiş check-in'leri getirir (kendi kayıtları hariç).
  ///
  /// Sunucu RLS (`is_active`, `is_hidden`) ile uyumlu satırlar döner.
  /// [CheckinModel.isActive] ile süre / oy baskısı istemci tarafında doğrulanır.
  /// Limit: 50
  Future<List<CheckinModel>> getActiveCheckinsNearby() async {
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final response = await _db
          .from('checkins')
          .select(
            'id, user_id, spot_id, crowd_level, fish_density, fish_species, photo_url, exif_verified, is_hidden, true_votes, false_votes, created_at, expires_at',
          )
          .eq('is_hidden', false)
          .neq('user_id', uid)
          .order('created_at', ascending: false)
          .range(0, 49);

      final list = response.map<CheckinModel>(CheckinModel.fromJson).toList();
      return list.where((c) => c.isActive).toList();
    } on PostgrestException catch (e) {
      throw Exception('Aktif check-in listesi alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Aktif check-in listesi alınamadı: $e');
    }
  }

  /// Yeni bir check-in kaydı oluşturur.
  Future<CheckinModel?> addCheckin(Map<String, dynamic> data) async {
    try {
      final response = await _db
          .from('checkins')
          .insert(data)
          .select(
            'id, user_id, spot_id, crowd_level, fish_density, fish_species, photo_url, exif_verified, is_hidden, true_votes, false_votes, created_at, expires_at',
          )
          .single();
      return CheckinModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('aktif bir bildirim')) {
        throw Exception('Bu mera için zaten aktif bildirim var! 2 saat bekleyin. ⏳');
      }
      throw Exception('Bildirim oluşturulamadı: ${e.message}');
    } catch (e) {
      if (e.toString().contains('aktif bir bildirim')) {
        throw Exception('Bu mera için zaten aktif bildirim var! 2 saat bekleyin. ⏳');
      }
      throw Exception('Bildirim oluşturulamadı: $e');
    }
  }

  /// Belirli mera için son 6 saatlik check-in kayıtlarını kullanıcı adıyla döner.
  /// Oy sayıları `checkins.true_votes` / `false_votes` (tetikleyici ile senkron).
  Future<List<CheckinModel>> getCheckinsForSpot(String spotId) async {
    try {
      final threshold = DateTime.now().subtract(
        const Duration(hours: AppConstants.checkinRemoveHours),
      );
      final response = await _db
          .from('checkins')
          .select('*, users:user_id(username)')
          .eq('spot_id', spotId)
          .eq('is_hidden', false)
          .gte('created_at', threshold.toIso8601String())
          .order('created_at', ascending: false);
      return response.map<CheckinModel>(CheckinModel.fromJson).toList();
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
  /// Toggle: aynı değer → satır silinir.
  /// Farklı değer / ilk oy → tek `upsert` (atomik).
  Future<void> castVote({
    required String checkinId,
    required String voterId,
    required bool voteValue,
  }) async {
    try {
      final existing = await getUserVote(checkinId, voterId);
      if (existing == voteValue) {
        await _unvote(checkinId: checkinId, voterId: voterId);
        return;
      }

      await _db.from('checkin_votes').upsert(
        {
          'checkin_id': checkinId,
          'voter_id': voterId,
          'vote': voteValue,
        },
        onConflict: 'checkin_id,voter_id',
      );
    } on PostgrestException catch (e) {
      throw Exception('Oylama gönderilemedi: ${e.message}');
    } catch (e) {
      throw Exception('Oylama gönderilemedi: $e');
    }
  }

  Future<void> _unvote({
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

  /// Oy sonrası: sunucu tetikleyicisi `is_hidden` günceller. İstemci doğrular;
  /// tetikleyici yoksa `is_hidden` için yedek UPDATE dener.
  ///
  /// [checkinWasVisible]: oy öncesi bu bildirim listede görünür müydü (`!checkin.isHidden`).
  /// Dönüş: **yeni** gizlendi mi (önce görünür + şimdi gizli) — `ScoreService.wrongReport` için.
  ///
  /// Gizleme başarısız olursa (RLS vb.) exception fırlatır; oy kaydı geri alınmaz.
  Future<bool> evaluateAndHide(
    String checkinId, {
    required bool checkinWasVisible,
  }) async {
    if (!checkinWasVisible) {
      return false;
    }

    try {
      var row = await _db
          .from('checkins')
          .select('is_hidden, true_votes, false_votes')
          .eq('id', checkinId)
          .maybeSingle();

      if (row == null) {
        throw Exception('Bildirim bulunamadı.');
      }

      if (row['is_hidden'] == true) {
        return checkinWasVisible;
      }

      final tv = (row['true_votes'] as num?)?.toInt() ?? 0;
      final fv = (row['false_votes'] as num?)?.toInt() ?? 0;
      final total = tv + fv;
      final shouldHide = total >= AppConstants.minVotesForHide &&
          total > 0 &&
          (fv / total) >= AppConstants.voteThresholdPercent;

      if (!shouldHide) {
        return false;
      }

      await _db.from('checkins').update({'is_hidden': true}).eq('id', checkinId);

      row = await _db
          .from('checkins')
          .select('is_hidden')
          .eq('id', checkinId)
          .maybeSingle();

      if (row == null || row['is_hidden'] != true) {
        throw Exception(
          'Bildirim gizlenemedi. Sunucu politikası veya bağlantı sorunu olabilir.',
        );
      }

      return true;
    } on PostgrestException catch (e) {
      throw Exception('Bildirim gizlenemedi: ${e.message}');
    }
  }

  /// Oy sayıları — `checkins` sayaç kolonları (tetikleyici ile uyumlu).
  Future<Map<bool, int>> getVoteCounts(String checkinId) async {
    try {
      final row = await _db
          .from('checkins')
          .select('true_votes, false_votes')
          .eq('id', checkinId)
          .single();
      return {
        true: (row['true_votes'] as num?)?.toInt() ?? 0,
        false: (row['false_votes'] as num?)?.toInt() ?? 0,
      };
    } on PostgrestException catch (e) {
      throw Exception('Oy sayıları alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Oy sayıları alınamadı: $e');
    }
  }
}
