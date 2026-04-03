import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';

// cleaned: offline-first metotlar eklendi (H7), mevcut API korundu

/// Balık günlüğü repository — offline-first H7.
/// Önce Drift'e yaz, isSynced=false → arka planda Supabase'e sync et.
class FishLogRepository {
  final _remote = SupabaseService.client;
  final _local = AppDatabase.instance;

  // ─── REMOTE ──────────────────────────────────────────────

  /// Fotoğrafı Supabase Storage'a yükler.
  Future<void> uploadPhoto({
    required File file,
    required String storagePath,
  }) async {
    try {
      await SupabaseService.storage
          .from('fish-photos')
          .upload(storagePath, file);
    } on StorageException catch (e) {
      throw Exception('Fotoğraf yüklenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Fotoğraf yüklenemedi: $e');
    }
  }

  /// Kullanıcının günlük kayıtlarını döner — remote önce, hata durumunda cache.
  Future<List<FishLogModel>> getMyLogs(String userId) async {
    try {
      final response = await _remote
          .from('fish_logs')
          .select('id, user_id, spot_id, species, weight, length, photo_url, exif_verified, weather_snapshot, is_private, released, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final logs = response.map<FishLogModel>(FishLogModel.fromJson).toList();
      await _cacheLogsLocally(logs);
      return logs;
    } catch (_) {
      return getCachedLogs(userId);
    }
  }

  /// Yeni kayıt — önce remote, offline ise local + sync kuyruğu.
  Future<FishLogModel?> addLog(Map<String, dynamic> data) async {
    try {
      final response =
          await _remote.from('fish_logs').insert(data).select('id, user_id, spot_id, species, weight, length, photo_url, exif_verified, weather_snapshot, is_private, released, created_at').single();
      final log = FishLogModel.fromJson(response);
      await _upsertLocalLog(log, isSynced: true);
      return log;
    } catch (_) {
      final tempId =
          'offline_${DateTime.now().millisecondsSinceEpoch}';
      final offlineData = {
        ...data,
        'id': tempId,
        'created_at': DateTime.now().toIso8601String(),
      };
      final log = FishLogModel.fromJson(offlineData);
      await _upsertLocalLog(log, isSynced: false);
      await _enqueueSync('insert', 'fish_logs', data);
      return log;
    }
  }

  /// Offline-first kayıt oluşturma — mevcut ekran API'siyle uyumlu.
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
      final response = await _remote
          .from('fish_logs')
          .insert(data)
          .select('id, user_id, spot_id, species, weight, length, photo_url, exif_verified, weather_snapshot, is_private, released, created_at')
          .single();
      return FishLogModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı oluşturulamadı: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı oluşturulamadı: $e');
    }
  }

  /// Kayıt günceller.
  Future<void> updateLog(String id, Map<String, dynamic> updates) async {
    try {
      await _remote.from('fish_logs').update(updates).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı güncellenemedi: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı güncellenemedi: $e');
    }
  }

  /// Kayıt siler (remote + local).
  Future<void> deleteLog(String id) async {
    try {
      await _remote.from('fish_logs').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı silinemedi: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı silinemedi: $e');
    }
    await (_local.delete(_local.localFishLogs)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Tür bazlı istatistik.
  Future<Map<String, int>> getSpeciesStats(String userId) async {
    final logs = await getMyLogs(userId);
    final stats = <String, int>{};
    for (final log in logs) {
      stats[log.species] = (stats[log.species] ?? 0) + 1;
    }
    return stats;
  }

  /// Genel istatistik.
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
      if (log.weight != null) totalWeight += log.weight!;
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
      'topSpecies':
          topSpecies.map((e) => {'species': e.key, 'count': e.value}).toList(),
      'bestSpotId': bestSpotId,
      'totalWeightKg': totalWeight,
    };
  }

  /// Kullanıcının toplam av kaydı sayısı.
  Future<int> getLogCount(String userId) async {
    try {
      final response = await _remote
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

  // ─── LOCAL (DRIFT) ────────────────────────────────────────

  /// Drift cache'den kayıtları döner.
  Future<List<FishLogModel>> getCachedLogs(String userId) async {
    final rows = await (_local.select(_local.localFishLogs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_localToModel).toList();
  }

  /// Sync edilmemiş kayıtları Supabase'e gönderir.
  Future<void> syncPendingLogs() async {
    final pending = await (_local.select(_local.localFishLogs)
          ..where((t) => t.isSynced.equals(false)))
        .get();
    for (final row in pending) {
      try {
        final data = {
          'user_id': row.userId,
          'spot_id': row.spotId,
          'species': row.species,
          'weight': row.weight,
          'length': row.length,
          'photo_url': row.photoUrl,
          'weather_snapshot': row.weatherSnapshot != null
              ? jsonDecode(row.weatherSnapshot!)
              : null,
          'is_private': row.isPrivate,
          'released': row.released,
          'created_at': row.createdAt.toIso8601String(),
        };
        await _remote.from('fish_logs').insert(data);
        await (_local.update(_local.localFishLogs)
              ..where((t) => t.id.equals(row.id)))
            .write(const LocalFishLogsCompanion(isSynced: Value(true)));
      } catch (_) {
        // Sonraki sync denemesinde tekrar denenecek
      }
    }
  }

  // ─── YARDIMCI ────────────────────────────────────────────

  Future<void> _cacheLogsLocally(List<FishLogModel> logs) async {
    for (final log in logs) {
      await _upsertLocalLog(log, isSynced: true);
    }
  }

  Future<void> _upsertLocalLog(FishLogModel log,
      {required bool isSynced}) async {
    await _local.into(_local.localFishLogs).insertOnConflictUpdate(
          LocalFishLogsCompanion(
            id: Value(log.id),
            userId: Value(log.userId),
            spotId: Value(log.spotId),
            species: Value(log.species),
            weight: Value(log.weight),
            length: Value(log.length),
            photoUrl: Value(log.photoUrl),
            weatherSnapshot: Value(
              log.weatherSnapshot != null
                  ? jsonEncode(log.weatherSnapshot)
                  : null,
            ),
            isPrivate: Value(log.isPrivate),
            released: Value(log.released),
            isSynced: Value(isSynced),
            createdAt: Value(log.createdAt),
          ),
        );
  }

  Future<void> _enqueueSync(
      String operation, String tableName, Map<String, dynamic> payload) async {
    await _local.into(_local.syncQueue).insert(
          SyncQueueCompanion(
            operation: Value(operation),
            tableNameValue: Value(tableName),
            payload: Value(jsonEncode(payload)),
          ),
        );
  }

  FishLogModel _localToModel(LocalFishLog row) => FishLogModel(
        id: row.id,
        userId: row.userId,
        spotId: row.spotId,
        species: row.species,
        weight: row.weight,
        length: row.length,
        photoUrl: row.photoUrl,
        weatherSnapshot: row.weatherSnapshot != null
            ? jsonDecode(row.weatherSnapshot!) as Map<String, dynamic>
            : null,
        isPrivate: row.isPrivate,
        released: row.released,
        createdAt: row.createdAt,
      );
}
