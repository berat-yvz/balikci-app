import 'package:isar/isar.dart';
import 'package:balikci_app/data/local/local_spot.dart';

part 'sync_queue.g.dart';

/// Offline sync kuyruğu — bağlantı yokken yapılan işlemler.
/// Bağlantı gelince IsarService + bu kuyruk taranarak Supabase'e gönderilir.
@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;

  late String action; // 'insert' | 'update' | 'delete'
  late String table; // 'fish_logs' | 'checkins' | vb.
  late String payload; // JSON string
  late DateTime createdAt;
  late int retryCount;
}
