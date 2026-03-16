import 'package:drift/drift.dart';

/// Offline sync kuyruğu tablosu.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName => text()(); // örn: 'fish_logs'
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get payload => text()(); // JSON data
  DateTimeColumn get createdAt => dateTime()();
}
