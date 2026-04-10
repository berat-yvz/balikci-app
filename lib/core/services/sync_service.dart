import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;

/// Offline işlem kuyruğunu yöneten servis.
///
/// - `connectivity_plus` ile anlık online geçişini yakalar → sıfır gecikme sync.
/// - Yedek olarak 30 sn'de bir poll yapar (deep-sleep durumu için).
class SyncService {
  SyncService._() : _db = AppDatabase.instance;

  static final SyncService instance = SyncService._();

  final AppDatabase _db;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pollTimer;
  bool _processing = false;
  bool _wasOffline = false;

  /// Kuyruğa yeni bir işlem kaydı ekler.
  Future<void> enqueue(
    String operation,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    await _db.into(_db.syncQueue).insert(
      SyncQueueCompanion.insert(
        operation: operation,
        tableNameValue: tableName,
        payload: jsonEncode(payload),
      ),
    );
  }

  /// Kuyruktaki işlemleri sırayla Supabase'e yazar.
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      final rows = await (_db.select(
        _db.syncQueue,
      )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

      for (final row in rows) {
        try {
          final payload = jsonDecode(row.payload) as Map<String, dynamic>;
          final table = row.tableNameValue;
          switch (row.operation) {
            case 'insert':
              await SupabaseService.client.from(table).insert(payload);
            case 'update':
              if (payload['id'] == null) {
                throw Exception('Update payload içinde id alanı yok.');
              }
              final updateData = Map<String, dynamic>.from(payload)
                ..remove('id');
              await SupabaseService.client
                  .from(table)
                  .update(updateData)
                  .eq('id', payload['id']);
            case 'delete':
              if (payload['id'] == null) {
                throw Exception('Delete payload içinde id alanı yok.');
              }
              await SupabaseService.client
                  .from(table)
                  .delete()
                  .eq('id', payload['id']);
            default:
              throw Exception('Desteklenmeyen operasyon: ${row.operation}');
          }

          await (_db.delete(
            _db.syncQueue,
          )..where((t) => t.id.equals(row.id))).go();
        } catch (e) {
          final nextRetry = row.retryCount + 1;
          if (nextRetry > 5) {
            // Maksimum deneme aşıldı → sil
            await (_db.delete(
              _db.syncQueue,
            )..where((t) => t.id.equals(row.id))).go();
            debugPrint('SyncService: İşlem kalıcı hata — silindi: $e');
            continue;
          }
          await (_db.update(_db.syncQueue)..where((t) => t.id.equals(row.id)))
              .write(SyncQueueCompanion(retryCount: Value(nextRetry)));
          debugPrint('SyncService: Retry ${row.retryCount + 1}: $e');
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Bağlantı değişimlerini dinle + yedek periyodik poll başlat.
  void startListening() {
    // 1) connectivity_plus stream — offline→online geçişinde anlık tetikle
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && _wasOffline) {
        debugPrint('SyncService: Bağlantı geldi — kuyruk işleniyor.');
        await processQueue();
      }
      _wasOffline = !online;
    });

    // 2) İlk kontrol
    Connectivity().checkConnectivity().then((results) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      _wasOffline = !online;
      if (online) await processQueue();
    });

    // 3) Yedek poll — 30 sn (uygulama ön planda ama stream tetiklenmemişse)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) await processQueue();
    });
  }

  void dispose() {
    _connSub?.cancel();
    _pollTimer?.cancel();
  }
}
