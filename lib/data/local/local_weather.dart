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
  // Rüzgar yönü (derece, 0-360)
  IntColumn get windDirection => integer().nullable()();
  // Bulutluluk yüzdesi
  RealColumn get cloudCover => real().nullable()();
  // Görüş mesafesi (km)
  RealColumn get visibilityKm => real().nullable()();
  // Yağış miktarı (mm)
  RealColumn get precipitation => real().nullable()();
  // Deniz yüzey sıcaklığı (°C)
  RealColumn get seaSurfaceTemperature => real().nullable()();
  // Atmosferik basınç (hPa)
  RealColumn get pressureHpa => real().nullable()();
  // Tüm saatlik veri JSON olarak (hourly array)
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {regionKey};
}
