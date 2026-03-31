import 'package:drift/drift.dart';

/// Offline sync kuyruğu tablosu.
class SyncQueue extends Table {
  // cleaned: tablo alanları sprint kuralına göre standardize edildi
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get tableNameValue =>
      text().named('table_name')(); // örn: 'fish_logs'
  TextColumn get payload => text()(); // JSON data
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
