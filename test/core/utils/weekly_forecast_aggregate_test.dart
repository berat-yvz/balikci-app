import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:balikci_app/core/utils/weekly_forecast_aggregate.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';

String _isoHour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}:00';

HourlyWeatherModel _h(
  DateTime t, {
  required double temp,
  required int code,
  double precip = 0,
}) {
  return HourlyWeatherModel.fromOpenMeteo(
    timeStr: _isoHour(t),
    temperature: temp,
    windspeed: 10,
    precipitation: precip,
    weatherCode: code,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  test('buildWeeklyForecastRows boş liste döner', () {
    expect(buildWeeklyForecastRows([], DateTime(2026, 5, 9)), isEmpty);
  });

  test('dün verisi tabloya alınmaz; özet bugünden başlar', () {
    final now = DateTime(2026, 5, 9, 14);
    final yesterday = DateTime(2026, 5, 8, 13);
    final hourly = [
      _h(yesterday, temp: 14, code: 61, precip: 0.5),
      _h(DateTime(2026, 5, 9, 13), temp: 22, code: 0),
    ];
    final rows = buildWeeklyForecastRows(hourly, now);
    expect(rows.length, 1);
    expect(rows.single.dayLabel, 'Bugün');
    expect(rows.single.highC, 22);
    expect(rows.single.precipChancePercent, isNotNull);
  });

  test('bugün ve yarın iki satır üretir', () {
    final now = DateTime(2026, 5, 9, 10);
    final hourly = <HourlyWeatherModel>[];
    for (var i = 0; i < 24; i++) {
      hourly.add(_h(DateTime(2026, 5, 9, i), temp: 18 + i * 0.1, code: 2));
    }
    for (var i = 0; i < 24; i++) {
      hourly.add(_h(DateTime(2026, 5, 10, i), temp: 12 + i * 0.05, code: 3));
    }
    final rows = buildWeeklyForecastRows(hourly, now);
    expect(rows.length, 2);
    expect(rows[0].dayLabel, 'Bugün');
    expect(rows[1].dayLabel, 'Yarın');
    expect(rows[0].precipChancePercent, isNotNull);
  });

  test('gece kapalı bulut (WMO≥3): ay+bulut ikonu; gündüz yalnız bulut', () {
    final now = DateTime(2026, 5, 9, 12);
    final d = DateTime(2026, 5, 9);
    final hourly = <HourlyWeatherModel>[];
    for (var h = 0; h < 24; h++) {
      hourly.add(_h(DateTime(d.year, d.month, d.day, h), temp: 16, code: 3));
    }
    final row = buildWeeklyForecastRows(hourly, now).single;
    expect(row.dayVisual, WeeklyWeatherVisualKind.cloudy);
    expect(row.nightVisual, WeeklyWeatherVisualKind.partlyCloudyNight);
  });

  test('yağmurlu gündüz kodu: rain görsel türü', () {
    final now = DateTime(2026, 5, 9, 12);
    final d = DateTime(2026, 5, 9);
    final hourly = <HourlyWeatherModel>[];
    for (var h = 0; h < 24; h++) {
      hourly.add(_h(DateTime(d.year, d.month, d.day, h), temp: 14, code: 61));
    }
    final row = buildWeeklyForecastRows(hourly, now).single;
    expect(row.dayVisual, WeeklyWeatherVisualKind.rain);
    expect(row.nightVisual, WeeklyWeatherVisualKind.rain);
  });

  test('yüksek yağış olasılığında kapalı bulut kodu yağmur glifine çıkar', () {
    final now = DateTime(2026, 5, 9, 12);
    final d = DateTime(2026, 5, 9);
    final hourly = <HourlyWeatherModel>[];
    for (var h = 0; h < 24; h++) {
      hourly.add(
        _h(
          DateTime(d.year, d.month, d.day, h),
          temp: 15,
          code: 3,
          precip: h.isEven ? 0.3 : 0,
        ),
      );
    }
    final row = buildWeeklyForecastRows(hourly, now).single;
    expect(row.precipChancePercent, greaterThanOrEqualTo(38));
    expect(row.dayVisual, WeeklyWeatherVisualKind.rain);
    expect(row.nightVisual, WeeklyWeatherVisualKind.rain);
  });

  test('yedi günlük saatlik veriden yedi satır üretir', () {
    final now = DateTime(2026, 5, 9, 12);
    final hourly = <HourlyWeatherModel>[];
    for (var day = 0; day < 7; day++) {
      final base = DateTime(2026, 5, 9).add(Duration(days: day));
      for (var hour = 0; hour < 24; hour++) {
        hourly.add(
          _h(
            DateTime(base.year, base.month, base.day, hour),
            temp: 15 + day.toDouble(),
            code: 1,
          ),
        );
      }
    }
    final rows = buildWeeklyForecastRows(hourly, now);
    expect(rows.length, 7);
    expect(rows.first.dayLabel, 'Bugün');
    expect(rows[1].dayLabel, 'Yarın');
    expect(rows.last.highC, 15 + 6);
  });
}
