import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;

/// Offline işlem kuyruğunu yöneten servis.
class SyncService {
  // cleaned: kuyruk ekleme/işleme ve çevrimdışı senkron orkestrasyonu eklendi
  SyncService(this._db);

  final AppDatabase _db;
  Timer? _pollTimer;
  bool _processing = false;

  /// Kuyruğa yeni bir işlem kaydı ekler.
  Future<void> enqueue(
    String operation,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    await _db
        .into(_db.syncQueue)
        .insert(
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
              break;
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
              break;
            case 'delete':
              if (payload['id'] == null) {
                throw Exception('Delete payload içinde id alanı yok.');
              }
              await SupabaseService.client
                  .from(table)
                  .delete()
                  .eq('id', payload['id']);
              break;
            default:
              throw Exception('Desteklenmeyen operasyon: ${row.operation}');
          }

          await (_db.delete(
            _db.syncQueue,
          )..where((t) => t.id.equals(row.id))).go();
        } catch (_) {
          final nextRetry = row.retryCount + 1;
          if (nextRetry > 3) {
            await (_db.delete(
              _db.syncQueue,
            )..where((t) => t.id.equals(row.id))).go();
            continue;
          }
          await (_db.update(_db.syncQueue)..where((t) => t.id.equals(row.id)))
              .write(SyncQueueCompanion(retryCount: Value(nextRetry)));
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Ağ bağlantısı geldikçe kuyruğu otomatik işlemeyi başlatır.
  ///
  /// Not: Yeni paket eklemeden çalışmak için basit online kontrol + periyodik poll
  /// yaklaşımı kullanılır.
  void startListening() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (await _isOnline()) {
        await processQueue();
      }
    });
    unawaited(
      _isOnline().then((online) async {
        if (online) await processQueue();
      }),
    );
  }

  void dispose() {
    _pollTimer?.cancel();
  }

  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
