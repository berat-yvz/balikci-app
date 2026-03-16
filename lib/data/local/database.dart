import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:balikci_app/data/local/local_spot.dart';
import 'package:balikci_app/data/local/local_fish_log.dart';
import 'package:balikci_app/data/local/sync_queue.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LocalSpots, LocalFishLogs, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'balikci_db',
    native: const DriftNativeOptions(
      // SQLite ile web desteği vs ayarları burada yapılır
    ),
  );
}
