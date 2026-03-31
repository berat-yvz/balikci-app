import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';

// cleaned: duplicate sorgu azaltıldı ve public API belgeleri netleştirildi

/// Balık günlüğü repository — Supabase `fish_logs` tablosu.
class FishLogRepository {
  final SupabaseClient _db = SupabaseService.client;

  /// Kullanıcının günlük kayıtlarını varsayılan limit ile döner.
  Future<List<FishLogModel>> getMyLogs(String userId) async {
    return getLogs(userId, limit: 10000);
  }

  /// Yeni bir balık günlüğü kaydı oluşturur.
  Future<FishLogModel> createLog({
    required String userId,
    String? spotId,
    required String species,
    double? weightKg,
    double? lengthCm,
    String? notes,
    String? photoUrl,
    Map<String, dynamic>? weatherSnapshot,
    bool isPrivate = false,
    bool released = false,
  }) async {
    final data = <String, dynamic>{
      'user_id': userId,
      'species': species,
      'weight': weightKg,
      'length': lengthCm,
      'photo_url': photoUrl,
      'weather_snapshot': weatherSnapshot,
      'is_private': isPrivate,
      'released': released,
    };
    if (spotId != null) data['spot_id'] = spotId;
    if (notes != null && notes.trim().isNotEmpty) {
      data['notes'] = notes.trim();
    }

    try {
      final response = await _db
          .from('fish_logs')
          .insert(data)
          .select()
          .single();
      return FishLogModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception(
        'Günlük kaydı oluşturulurken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Günlük kaydı oluşturulamadı: $e');
    }
  }

  /// Kullanıcının günlük kayıtlarını tarih sırasına göre döner.
  Future<List<FishLogModel>> getLogs(String userId, {int limit = 50}) async {
    try {
      final response = await _db
          .from('fish_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return response.map<FishLogModel>(FishLogModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Exception('Günlük listesi alınırken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Günlük listesi alınamadı: $e');
    }
  }

  /// Mevcut günlük kaydını günceller.
  Future<void> updateLog(String id, Map<String, dynamic> updates) async {
    try {
      await _db.from('fish_logs').update(updates).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception(
        'Günlük kaydı güncellenirken bir hata oluştu: ${e.message}',
      );
    } catch (e) {
      throw Exception('Günlük kaydı güncellenemedi: $e');
    }
  }

  /// Günlük kaydını siler.
  Future<void> deleteLog(String id) async {
    try {
      await _db.from('fish_logs').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı silinirken bir hata oluştu: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı silinemedi: $e');
    }
  }

  /// Genel istatistik: toplam kayıt, en çok tutulan türler, en verimli mera, toplam ağırlık.
  Future<Map<String, dynamic>> getStats(String userId) async {
    final logs = await getMyLogs(userId);
    if (logs.isEmpty) {
      return {
        'totalLogs': 0,
        'topSpecies': <Map<String, dynamic>>[],
        'bestSpotId': null,
        'totalWeightKg': 0.0,
      };
    }

    final speciesCount = <String, int>{};
    final spotCount = <String, int>{};
    double totalWeight = 0;

    for (final log in logs) {
      speciesCount[log.species] = (speciesCount[log.species] ?? 0) + 1;
      if (log.spotId != null) {
        spotCount[log.spotId!] = (spotCount[log.spotId!] ?? 0) + 1;
      }
      if (log.weight != null) {
        totalWeight += log.weight!;
      }
    }

    final topSpecies = speciesCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String? bestSpotId;
    if (spotCount.isNotEmpty) {
      final best = spotCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      bestSpotId = best.first.key;
    }

    return {
      'totalLogs': logs.length,
      'topSpecies': topSpecies
          .map((e) => {'species': e.key, 'count': e.value})
          .toList(),
      'bestSpotId': bestSpotId,
      'totalWeightKg': totalWeight,
    };
  }

  /// Kullanıcının toplam av kaydı sayısı.
  Future<int> getLogCount(String userId) async {
    try {
      final response = await _db
          .from('fish_logs')
          .select('id')
          .eq('user_id', userId)
          .limit(10000);
      return (response as List).length;
    } on PostgrestException catch (e) {
      throw Exception('Kayıt sayısı alınamadı: ${e.message}');
    } catch (e) {
      throw Exception('Kayıt sayısı alınamadı: $e');
    }
  }
}
