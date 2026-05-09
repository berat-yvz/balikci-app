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

  test('dün verisi varsa ilk satır Dün ve yağış yüzdesi yok', () {
    final now = DateTime(2026, 5, 9, 14);
    final yesterday = DateTime(2026, 5, 8, 13);
    final hourly = [
      _h(yesterday, temp: 14, code: 61, precip: 0.5),
      _h(DateTime(2026, 5, 9, 13), temp: 22, code: 0),
    ];
    final rows = buildWeeklyForecastRows(hourly, now);
    expect(rows.first.dayLabel, 'Dün');
    expect(rows.first.precipChancePercent, isNull);
    expect(rows.first.highC, 14);
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
    expect(rows[1].dayLabel, 'Paz');
    expect(rows[0].precipChancePercent, isNotNull);
  });
}
