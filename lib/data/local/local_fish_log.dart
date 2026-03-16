import 'package:drift/drift.dart';

/// Offline balık günlüğü tablosu.
class LocalFishLogs extends Table {
  TextColumn get id => text()(); // Supabase UUID veya geçici offline ID
  TextColumn get userId => text()();
  TextColumn get spotId => text().nullable()();
  TextColumn get species => text()();
  RealColumn get weight => real().nullable()();
  RealColumn get length => real().nullable()();
  TextColumn get photoUrl => text().nullable()();
  BoolColumn get isPrivate => boolean()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
