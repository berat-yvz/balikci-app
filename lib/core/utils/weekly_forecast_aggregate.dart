import 'package:intl/intl.dart';

import 'package:balikci_app/data/models/hourly_weather_model.dart';

/// Günlük satırda gösterilecek küçük ikon türü (gündüz / gece slotuna göre).
enum WeeklyWeatherVisualKind {
  rain,
  partlyCloudyDay,
  partlyCloudyNight,
  cloudy,
  clearDay,
  clearNight,
}

/// Haftalık tablo için tek bir gün özeti.
class WeeklyForecastRow {
  final DateTime date;
  final String dayLabel;
  final int highC;
  final int lowC;

  /// null ise yağış yüzdesi ve damla ikonu gösterilmez (örn. "Dün").
  final int? precipChancePercent;
  final WeeklyWeatherVisualKind dayVisual;
  final WeeklyWeatherVisualKind nightVisual;

  const WeeklyForecastRow({
    required this.date,
    required this.dayLabel,
    required this.highC,
    required this.lowC,
    required this.precipChancePercent,
    required this.dayVisual,
    required this.nightVisual,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _hourLooksRainy(HourlyWeatherModel h) {
  final c = h.weatherCode;
  if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82) || (c >= 95 && c <= 99)) {
    return true;
  }
  return h.precipitation >= 0.2;
}

bool _rainWeatherCode(int c) =>
    (c >= 51 && c <= 67) || (c >= 80 && c <= 82) || (c >= 95 && c <= 99);

WeeklyWeatherVisualKind _visualFromCode(int code, {required bool night}) {
  if (_rainWeatherCode(code)) return WeeklyWeatherVisualKind.rain;
  if (code >= 3) return WeeklyWeatherVisualKind.cloudy;
  if (code == 2 || code == 1) {
    return night
        ? WeeklyWeatherVisualKind.partlyCloudyNight
        : WeeklyWeatherVisualKind.partlyCloudyDay;
  }
  return night
      ? WeeklyWeatherVisualKind.clearNight
      : WeeklyWeatherVisualKind.clearDay;
}

HourlyWeatherModel? _nearestHour(List<HourlyWeatherModel> hs, int targetHour) {
  if (hs.isEmpty) return null;
  HourlyWeatherModel? best;
  var bestDist = 999;
  for (final h in hs) {
    final d = (h.time.hour - targetHour).abs();
    if (d < bestDist) {
      bestDist = d;
      best = h;
    }
  }
  return best;
}

int? _precipChanceApprox(List<HourlyWeatherModel> hours) {
  if (hours.isEmpty) return 0;
  final rainy = hours.where(_hourLooksRainy).length;
  var pct = (rainy / hours.length * 100).round();
  final heavy = hours.any((h) => h.precipitation >= 1.0);
  if (heavy && pct < 35) pct = 45;
  return pct.clamp(0, 99);
}

String _dayLabel(DateTime date, DateTime todayOnly) {
  final d = _dateOnly(date);
  final yesterday = todayOnly.subtract(const Duration(days: 1));
  if (d == yesterday) return 'Dün';
  if (d == todayOnly) return 'Bugün';
  return DateFormat.E('tr_TR').format(date);
}

/// Saatlik tahminden en fazla 8 günlük satır üretir (mümkünse dün + bugün + önümüzdeki 6 gün).
List<WeeklyForecastRow> buildWeeklyForecastRows(
  List<HourlyWeatherModel> hourly,
  DateTime now,
) {
  if (hourly.isEmpty) return [];

  final todayOnly = _dateOnly(now);
  final yesterdayOnly = todayOnly.subtract(const Duration(days: 1));

  final byDay = <DateTime, List<HourlyWeatherModel>>{};
  for (final h in hourly) {
    final k = _dateOnly(h.time);
    byDay.putIfAbsent(k, () => []).add(h);
  }

  final ordered = <DateTime>[];
  if (byDay.containsKey(yesterdayOnly)) ordered.add(yesterdayOnly);

  for (var i = 0; i < 7 && ordered.length < 8; i++) {
    final d = todayOnly.add(Duration(days: i));
    if (byDay.containsKey(d) && !ordered.contains(d)) ordered.add(d);
  }

  if (ordered.length < 8) {
    final rest = byDay.keys.where((k) => !ordered.contains(k)).toList()
      ..sort();
    for (final k in rest) {
      if (ordered.length >= 8) break;
      if (k.isBefore(yesterdayOnly)) continue;
      ordered.add(k);
    }
  }

  final rows = <WeeklyForecastRow>[];
  for (final date in ordered) {
    final hours = byDay[date];
    if (hours == null || hours.isEmpty) continue;

    final high = hours.map((h) => h.temperature).reduce((a, b) => a > b ? a : b);
    final low = hours.map((h) => h.temperature).reduce((a, b) => a < b ? a : b);

    final daySample = _nearestHour(hours, 13) ?? hours.first;
    final nightSample = _nearestHour(hours, 22) ?? hours.last;

    final isYesterday = _dateOnly(date) == yesterdayOnly;
    final precip = isYesterday ? null : _precipChanceApprox(hours);

    rows.add(
      WeeklyForecastRow(
        date: date,
        dayLabel: _dayLabel(date, todayOnly),
        highC: high.round(),
        lowC: low.round(),
        precipChancePercent: precip,
        dayVisual: _visualFromCode(daySample.weatherCode, night: false),
        nightVisual: _visualFromCode(nightSample.weatherCode, night: true),
      ),
    );
  }

  return rows;
}
