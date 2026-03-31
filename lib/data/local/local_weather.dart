import 'package:drift/drift.dart';

/// Offline hava cache tablosu.
class LocalWeather extends Table {
  // cleaned: H9 için yerel hava cache tablosu eklendi
  TextColumn get regionKey => text()();
  RealColumn get tempC => real().nullable()();
  RealColumn get windSpeedKmh => real().nullable()();
  RealColumn get waveHeightM => real().nullable()();
  RealColumn get humidity => real().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {regionKey};
}
