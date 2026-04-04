import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:balikci_app/data/local/local_fish_log.dart';
import 'package:balikci_app/data/local/local_spot.dart';
import 'package:balikci_app/data/local/local_weather.dart';
import 'package:balikci_app/data/local/sync_queue.dart';

part 'database.g.dart';

/// H7 — Balık günlüğü tablosu (Supabase fish_logs şemasıyla uyumlu).
/// UUID alanlar SQLite'ta TEXT olarak saklanır.
class FishLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get spotId => text().nullable()();
  TextColumn get fishType => text()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get lengthCm => real().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get isReleased => boolean().withDefault(const Constant(false))();
  TextColumn get weatherSnapshot => text().nullable()();
  DateTimeColumn get caughtAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalSpots, LocalFishLogs, FishLogs, SyncQueue, LocalWeather])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 6;

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
      if (from < 6) {
        await m.createTable(fishLogs);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'balikci_app.db');
}
