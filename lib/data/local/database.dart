import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:balikci_app/data/local/local_fish_log.dart';
import 'package:balikci_app/data/local/local_spot.dart';
import 'package:balikci_app/data/local/local_weather.dart';
import 'package:balikci_app/data/local/sync_queue.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LocalSpots, LocalFishLogs, SyncQueue, LocalWeather])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(localSpots, localSpots.verified);
        await m.addColumn(localSpots, localSpots.muhtarId);
        await m.addColumn(localSpots, localSpots.cachedAt);
      }
      if (from < 3) {
        await m.createTable(localWeather);
      }
      if (from < 4) {
        await m.addColumn(syncQueue, syncQueue.tableNameValue);
        await m.addColumn(syncQueue, syncQueue.retryCount);
      }
      if (from < 5) {
        // LocalFishLogs: released ve weatherSnapshot eklendi (H7)
        await m.addColumn(
            localFishLogs, localFishLogs.released as GeneratedColumn<Object>);
        await m.addColumn(localFishLogs,
            localFishLogs.weatherSnapshot as GeneratedColumn<Object>);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'balikci_app.db');
}
