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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // LocalSpots: fishing_spots cache alanlari ile hizala
            await m.addColumn(localSpots, localSpots.verified);
            await m.addColumn(localSpots, localSpots.muhtarId);
            await m.addColumn(localSpots, localSpots.cachedAt);
          }
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'balikci_app.db',
  );
}
