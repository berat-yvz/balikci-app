import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:balikci_app/data/local/local_post.dart';
import 'package:balikci_app/data/local/local_spot.dart';
import 'package:balikci_app/data/local/local_weather.dart';
import 'package:balikci_app/data/local/sync_queue.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [LocalSpots, SyncQueue, LocalWeather, LocalPosts],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 9;

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
      if (from < 7) {
        await m.addColumn(localWeather,
            localWeather.windDirection as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.cloudCover as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.visibilityKm as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.precipitation as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.seaSurfaceTemperature as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.pressureHpa as GeneratedColumn<Object>);
        await m.addColumn(localWeather,
            localWeather.dataJson as GeneratedColumn<Object>);
      }
      if (from < 8) {
        await m.createTable(localPosts);
      }
      if (from < 9) {
        await customStatement('DROP TABLE IF EXISTS local_fish_logs;');
        await customStatement('DROP TABLE IF EXISTS fish_logs;');
      }
    },
  );

  // ─── LocalPosts CRUD ──────────────────────────────────────────────────────

  /// Postu önbelleğe yazar; aynı id varsa günceller.
  Future<void> savePost(LocalPostsCompanion post) async {
    await into(localPosts).insertOnConflictUpdate(post);
  }

  /// Önbellekten post listesi döner.
  /// [before] verilirse o tarihten önceki kayıtlar döner (cursor pagination).
  Future<List<LocalPost>> getLocalPosts({
    int limit = 20,
    DateTime? before,
  }) {
    final query = select(localPosts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);

    if (before != null) {
      query.where((t) => t.createdAt.isSmallerThanValue(before));
    }

    return query.get();
  }

  /// Tek bir postu önbellekten siler.
  Future<void> deleteLocalPost(String id) async {
    await (delete(localPosts)..where((t) => t.id.equals(id))).go();
  }

  /// Tüm yerel post önbelleğini temizler.
  Future<void> clearLocalPosts() async {
    await delete(localPosts).go();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'balikci_app.db');
}
