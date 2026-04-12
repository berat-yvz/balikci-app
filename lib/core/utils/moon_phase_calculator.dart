import 'dart:math' as math;

/// Julian Day tabanlı ay aydınlanması ve Türkçe faz adı.
/// Harici paket veya ağ yok.
class MoonPhaseCalculator {
  MoonPhaseCalculator._();

  /// Ortalama sinodik ay (gün).
  static const double _synodicMonth = 29.530588861;

  /// Referans yeni ay — 6 Ocak 2000, 18:14 UTC (yaygın ephemeris referansı).
  static final DateTime _referenceNewMoonUtc =
      DateTime.utc(2000, 1, 6, 18, 14);

  static final double _jdReferenceNewMoon = julianDay(_referenceNewMoonUtc);

  /// Gregorian tarih için Julian Day (UTC).
  static double julianDay(DateTime date) {
    final utc = date.toUtc();
    var y = utc.year;
    var m = utc.month;
    final d = utc.day +
        (utc.hour + (utc.minute + utc.second / 60) / 60) / 24;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }

  /// Ay yüzeyinin aydınlanmış oranı [0.0, 1.0] — JD farkı + sinodik ay.
  static double getMoonIllumination(DateTime date) {
    final jd = julianDay(date);
    var daysSince = jd - _jdReferenceNewMoon;
    daysSince %= _synodicMonth;
    if (daysSince < 0) {
      daysSince += _synodicMonth;
    }
    final phase = daysSince / _synodicMonth;
    return (1 - math.cos(2 * math.pi * phase)) / 2;
  }

  /// [getMoonIllumination] ile uyumlu Türkçe faz adı (`moon_phase_rules.json` aralıklarıyla uyumlu).
  static String getMoonPhaseName(double illumination) {
    if (illumination < 0.12) return 'Yeni Ay';
    if (illumination < 0.38) return 'İlk Hilal';
    if (illumination < 0.46) return 'İlk Dördün';
    if (illumination < 0.54) return 'Şişen Ay';
    if (illumination < 0.68) return 'Dolunay';
    if (illumination < 0.82) return 'Azalan Ay';
    if (illumination < 0.92) return 'Son Dördün';
    return 'Eğrilen Ay';
  }

  /// `fish_species_istanbul.json` ve `moon_phase_rules.json` ile eşleşen anahtar.
  static String phaseIdForIllumination(double illumination) {
    if (illumination < 0.12) return 'new_moon';
    if (illumination < 0.38) return 'waxing_crescent';
    if (illumination < 0.46) return 'first_quarter';
    if (illumination < 0.54) return 'waxing_gibbous';
    if (illumination < 0.68) return 'full_moon';
    if (illumination < 0.82) return 'waning_gibbous';
    if (illumination < 0.92) return 'last_quarter';
    return 'waning_crescent';
  }
}
