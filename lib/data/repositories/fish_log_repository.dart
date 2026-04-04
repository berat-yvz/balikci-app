import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import '../../data/local/database.dart';

class FishLogRepository {
  final AppDatabase _db;

  FishLogRepository(this._db);

  // Tüm kayıtları getir (önce local, sonra remote sync)
  Future<List<FishLog>> getLogs() async {
    return await _db.select(_db.fishLogs).get();
  }

  // Sadece senkronize edilmemiş kayıtları getir
  Future<List<FishLog>> getUnsyncedLogs() async {
    return await (_db.select(_db.fishLogs)
          ..where((t) => t.synced.equals(false)))
        .get();
  }

  // Yeni kayıt ekle (önce local Drift'e, sonra Supabase'e)
  Future<void> addLog({
    required String userId,
    required String fishType,
    String? spotId,
    double? weightKg,
    double? lengthCm,
    String? photoUrl,
    String? notes,
    bool isPrivate = false,
    bool isReleased = false,
    Map<String, dynamic>? weatherSnapshot,
    DateTime? caughtAt,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    // Önce Drift'e yaz (offline-first)
    await _db.into(_db.fishLogs).insert(
          FishLogsCompanion.insert(
            id: id,
            userId: userId,
            fishType: fishType,
            spotId: Value(spotId),
            weightKg: Value(weightKg),
            lengthCm: Value(lengthCm),
            photoUrl: Value(photoUrl),
            notes: Value(notes),
            isPrivate: Value(isPrivate),
            isReleased: Value(isReleased),
            weatherSnapshot: Value(
              weatherSnapshot != null ? jsonEncode(weatherSnapshot) : null,
            ),
            caughtAt: Value(caughtAt ?? now),
            synced: const Value(false),
          ),
        );

    // Supabase'e sync et
    await _syncLog(id, userId, fishType, spotId, weightKg, lengthCm,
        photoUrl, notes, isPrivate, isReleased, weatherSnapshot, caughtAt ?? now);
  }

  Future<void> _syncLog(
    String id,
    String userId,
    String fishType,
    String? spotId,
    double? weightKg,
    double? lengthCm,
    String? photoUrl,
    String? notes,
    bool isPrivate,
    bool isReleased,
    Map<String, dynamic>? weatherSnapshot,
    DateTime caughtAt,
  ) async {
    try {
      await SupabaseService.client.from('fish_logs').insert({
        'id': id,
        'user_id': userId,
        'fish_type': fishType,
        'spot_id': spotId,
        'weight_kg': weightKg,
        'length_cm': lengthCm,
        'photo_url': photoUrl,
        'notes': notes,
        'is_private': isPrivate,
        'is_released': isReleased,
        'weather_snapshot': weatherSnapshot,
        'caught_at': caughtAt.toIso8601String(),
        'synced': true,
      });

      // Sync başarılıysa local kaydı güncelle
      await (_db.update(_db.fishLogs)
            ..where((t) => t.id.equals(id)))
          .write(const FishLogsCompanion(synced: Value(true)));
    } catch (_) {
      // Internet yoksa synced=false kalır, daha sonra sync edilir
    }
  }

  // Bekleyen kayıtları Supabase'e gönder
  Future<void> syncPendingLogs() async {
    final unsyncedLogs = await getUnsyncedLogs();
    for (final log in unsyncedLogs) {
      await _syncLog(
        log.id,
        log.userId,
        log.fishType,
        log.spotId,
        log.weightKg,
        log.lengthCm,
        log.photoUrl,
        log.notes,
        log.isPrivate,
        log.isReleased,
        log.weatherSnapshot != null
            ? jsonDecode(log.weatherSnapshot!) as Map<String, dynamic>
            : null,
        log.caughtAt,
      );
    }
  }

  // Kaydı sil
  Future<void> deleteLog(String id) async {
    await (_db.delete(_db.fishLogs)..where((t) => t.id.equals(id))).go();
    try {
      await SupabaseService.client
          .from('fish_logs')
          .delete()
          .eq('id', id);
    } catch (_) {}
  }
}

final fishLogRepositoryProvider = Provider<FishLogRepository>((ref) {
  return FishLogRepository(AppDatabase.instance);
});
