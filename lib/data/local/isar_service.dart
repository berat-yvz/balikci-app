import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:balikci_app/data/local/local_spot.dart';
import 'package:balikci_app/data/local/local_fish_log.dart';
import 'package:balikci_app/data/local/sync_queue.dart';

/// Isar local DB yönetimi — offline-first yapının kalbi.
/// H7 sprint'te tam kapasiteye taşınacak.
class IsarService {
  IsarService._();

  static Isar? _isar;

  static Future<void> initialize() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [LocalSpotSchema, LocalFishLogSchema, SyncQueueItemSchema],
      directory: dir.path,
    );
  }

  static Isar get db {
    assert(_isar != null, 'IsarService.initialize() önce çağrılmalı!');
    return _isar!;
  }
}
