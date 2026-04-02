import 'package:drift/drift.dart';

/// Offline balık günlüğü tablosu — H7.
/// schemaVersion 4→5 ile released ve weatherSnapshot eklendi.
class LocalFishLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get spotId => text().nullable()();
  TextColumn get species => text()();
  RealColumn get weight => real().nullable()();
  RealColumn get length => real().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get weatherSnapshot => text().nullable()(); // JSON string
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get released => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
