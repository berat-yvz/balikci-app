import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../data/local/database.dart';
import '../../data/models/fish_log_model.dart';

/// Balık günlüğü repository — Supabase + Drift önbellek.
class FishLogRepository {
  final AppDatabase _db;
  final _remote = SupabaseService.client;

  FishLogRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Kullanıcının günlük kayıtlarını döner — remote önce, hata durumunda cache.
  Future<List<FishLogModel>> getMyLogs(String userId) async {
    try {
      final response = await _remote
          .from('fish_logs')
          .select(
            'id, user_id, spot_id, species, weight, length, photo_url, weather_snapshot, is_private, released, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final logs = response.map<FishLogModel>(FishLogModel.fromJson).toList();
      await _cacheLogsLocally(logs);
      return logs;
    } catch (_) {
      return getCachedLogs(userId);
    }
  }

  /// Yeni kayıt — doğrudan Supabase (ekran: `AddLogScreen`).
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
    Map<String, dynamic>? mergedWeather = weatherSnapshot;
    if (notes != null && notes.trim().isNotEmpty) {
      mergedWeather = Map<String, dynamic>.from(weatherSnapshot ?? {});
      mergedWeather['notes'] = notes.trim();
    }

    final data = <String, dynamic>{
      'user_id': userId,
      'species': species,
      'weight': weightKg,
      'length': lengthCm,
      'photo_url': photoUrl,
      'weather_snapshot': mergedWeather,
      'is_private': isPrivate,
      'released': released,
    };
    if (spotId != null) data['spot_id'] = spotId;

    try {
      final response = await _remote
          .from('fish_logs')
          .insert(data)
          .select(
            'id, user_id, spot_id, species, weight, length, photo_url, weather_snapshot, is_private, released, created_at',
          )
          .single();
      final newLog = FishLogModel.fromJson(response);
      // Gölge puan hesapla (fire-and-forget, UX'i engelleme)
      if (newLog.spotId != null) {
        unawaited(
          _remote.functions.invoke(
            'shadow-point-calculator',
            body: {
              'fish_log_id': newLog.id,
              'user_id': _remote.auth.currentUser!.id,
            },
          ),
        );
      }
      return newLog;
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı oluşturulamadı: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı oluşturulamadı: $e');
    }
  }

  /// Kayıt siler (remote + local + Storage fotoğraf).
  Future<void> deleteLog(String id) async {
    // Adım 1: Silmeden önce photo_url'yi çek
    String? photoUrl;
    try {
      final row = await _remote
          .from('fish_logs')
          .select('photo_url')
          .eq('id', id)
          .maybeSingle();
      photoUrl = row?['photo_url'] as String?;
    } catch (_) {
      // photo_url alınamazsa Storage silmeyi atlayacağız
    }

    // Adım 2: DB kaydını sil
    try {
      await _remote.from('fish_logs').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Günlük kaydı silinemedi: ${e.message}');
    } catch (e) {
      throw Exception('Günlük kaydı silinemedi: $e');
    }
    await (_db.delete(_db.localFishLogs)..where((t) => t.id.equals(id))).go();
    await (_db.delete(_db.fishLogs)..where((t) => t.id.equals(id))).go();

    // Adım 3: Storage'dan fotoğrafı sil (DB silme başarılıysa)
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final path = _extractStoragePath(photoUrl);
      if (path != null) {
        try {
          await SupabaseService.client.storage
              .from('fish-photos')
              .remove([path]);
        } catch (e) {
          debugPrint('Storage fotoğraf silme hatası (görmezden gelindi): $e');
        }
      }
    }
  }

  /// URL'den Storage path'ini çıkarır.
  /// Örnek URL: .../storage/v1/object/public/fish-photos/fish_logs/{uid}/...
  /// Döner: fish_logs/{uid}/dosyaadi.jpg
  String? _extractStoragePath(String url) {
    const marker = '/fish-photos/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    final path = url.substring(idx + marker.length);
    return path.isEmpty ? null : path;
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

  /// `FishLogs` Drift tablosunu döner — remote önce, hata durumunda local cache.
  Future<List<FishLog>> getLogs() async {
    final userId = SupabaseService.auth.currentUser?.id ?? '';
    try {
      final response = await _remote
          .from('fish_logs')
          .select(
            'id, user_id, spot_id, species, weight, length, photo_url, weather_snapshot, is_private, released, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      for (final row in response) {
        final rawWs = row['weather_snapshot'];
        Map<String, dynamic>? wsMap;
        if (rawWs is Map) {
          wsMap = Map<String, dynamic>.from(rawWs);
        }
        String? notesFromWs;
        if (wsMap != null && wsMap['notes'] != null) {
          notesFromWs = wsMap['notes'].toString();
        }
        await _db.into(_db.fishLogs).insertOnConflictUpdate(
              FishLogsCompanion(
                id: Value(row['id'] as String),
                userId: Value(row['user_id'] as String),
                spotId: Value(row['spot_id'] as String?),
                fishType: Value(row['species'] as String? ?? ''),
                weightKg: Value((row['weight'] as num?)?.toDouble()),
                lengthCm: Value((row['length'] as num?)?.toDouble()),
                photoUrl: Value(row['photo_url'] as String?),
                notes: Value(notesFromWs),
                isPrivate: Value(row['is_private'] as bool? ?? false),
                isReleased: Value(row['released'] as bool? ?? false),
                weatherSnapshot: Value(
                  wsMap != null ? jsonEncode(wsMap) : null,
                ),
                caughtAt: Value(
                  row['created_at'] != null
                      ? DateTime.parse(row['created_at'] as String)
                      : DateTime.now(),
                ),
                synced: const Value(true),
              ),
            );
      }
    } catch (_) {
      // offline: aşağıda local cache dönülecek
    }
    return (_db.select(_db.fishLogs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.caughtAt)]))
        .get();
  }

  /// Drift cache'den kayıtları döner.
  Future<List<FishLogModel>> getCachedLogs(String userId) async {
    final rows = await (_db.select(_db.localFishLogs)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_localToModel).toList();
  }

  Future<void> _cacheLogsLocally(List<FishLogModel> logs) async {
    for (final log in logs) {
      await _upsertLocalLog(log, isSynced: true);
    }
  }

  Future<void> _upsertLocalLog(
    FishLogModel log, {
    required bool isSynced,
  }) async {
    await _db.into(_db.localFishLogs).insertOnConflictUpdate(
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
