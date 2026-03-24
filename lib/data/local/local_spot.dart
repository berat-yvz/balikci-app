import 'package:drift/drift.dart';

/// Offline mera cache tablosu.
class LocalSpots extends Table {
  TextColumn get id => text()(); // Supabase UUID
  TextColumn get userId => text()();
  TextColumn get name => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get type => text().nullable()();
  TextColumn get privacyLevel => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get muhtarId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
