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

  // ── Solunar (İstanbul ~41.01°N, 28.97°E) — ±30 dk hedef tolerans ───────

  static const double istanbulLat = 41.01;
  static const double istanbulLon = 28.97;

  /// İstanbul yerel günü (UTC+3 sabit, yaz-kış DST yok).
  static DateTime istanbulCalendarDate(DateTime instant) {
    final tr = instant.toUtc().add(const Duration(hours: 3));
    return DateTime(tr.year, tr.month, tr.day);
  }

  /// O gün 00:00 İstanbul → UTC anı.
  static DateTime istanbulMidnightUtc(int year, int month, int day) {
    return DateTime.utc(year, month, day).subtract(const Duration(hours: 3));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;

  /// Greenwich mean sidereal time (derece).
  static double _gmstDegrees(double jd) {
    final d = jd - 2451545.0;
    var gmst = 280.46061837 + 360.98564736629 * d;
    gmst %= 360;
    if (gmst < 0) {
      gmst += 360;
    }
    return gmst;
  }

  /// Yerel yıldız saati (radyan).
  static double _localSiderealRad(double jd, double lonDeg) {
    var lstDeg = _gmstDegrees(jd) + lonDeg;
    lstDeg %= 360;
    if (lstDeg < 0) {
      lstDeg += 360;
    }
    return _deg2rad(lstDeg);
  }

  static double _normalizeHa(double ha) {
    var a = ha;
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  /// Yaklaşık ay RA/dec (rad) — suncalc/mini ephemeris.
  static (double ra, double dec) _moonRaDecRad(double jd) {
    final d = jd - 2451545.0;
    final L = _deg2rad((218.316 + 13.176396 * d) % 360);
    final M = _deg2rad((134.963 + 13.064993 * d) % 360);
    final F = _deg2rad((93.272 + 13.229350 * d) % 360);
    final lam = L + _deg2rad(6.289) * math.sin(M);
    final beta = _deg2rad(5.128) * math.sin(F);
    final e = _deg2rad(23.439281);
    final ra = math.atan2(
      math.sin(lam) * math.cos(e) - math.tan(beta) * math.sin(e),
      math.cos(lam),
    );
    final dec = math.asin(
      math.sin(beta) * math.cos(e) +
          math.cos(beta) * math.sin(e) * math.sin(lam),
    );
    return (ra, dec);
  }

  /// Ay yüksekliği (radyan), [utc] anında İstanbul gökyüzü.
  static double moonAltitudeRad(DateTime utc) {
    final jd = julianDay(utc);
    final (ra, dec) = _moonRaDecRad(jd);
    final lat = _deg2rad(istanbulLat);
    final lst = _localSiderealRad(jd, istanbulLon);
    final ha = _normalizeHa(lst - ra);
    return math.asin(
      math.sin(lat) * math.sin(dec) +
          math.cos(lat) * math.cos(dec) * math.cos(ha),
    );
  }

  /// İstanbul yerel [date] günü için major/minor solunar pencereleri (UTC).
  static List<SolunarPeriod> getSolunarPeriods(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;
    final t0 = istanbulMidnightUtc(y, m, d);
    const stepMinutes = 10;
    const windowMinutes = 36 * 60;

    var tMax = t0;
    var maxAlt = -10.0;
    DateTime? moonrise;
    DateTime? moonset;
    var prevAlt = moonAltitudeRad(t0);
    var prevT = t0;

    for (var i = 1; i <= windowMinutes ~/ stepMinutes; i++) {
      final t = t0.add(Duration(minutes: stepMinutes * i));
      final alt = moonAltitudeRad(t);
      if (alt > maxAlt) {
        maxAlt = alt;
        tMax = t;
      }
      if (prevAlt <= 0 && alt > 0) {
        moonrise ??= _interpolateCrossing(prevT, t, prevAlt, alt);
      }
      if (prevAlt > 0 && alt <= 0) {
        moonset ??= _interpolateCrossing(prevT, t, prevAlt, alt);
      }
      prevAlt = alt;
      prevT = t;
    }

    final tLower = tMax.add(const Duration(hours: 12));
    final periods = <SolunarPeriod>[
      SolunarPeriod(
        start: tMax.subtract(const Duration(hours: 1)),
        end: tMax.add(const Duration(hours: 1)),
        isMajor: true,
      ),
      SolunarPeriod(
        start: tLower.subtract(const Duration(hours: 1)),
        end: tLower.add(const Duration(hours: 1)),
        isMajor: true,
      ),
    ];

    if (moonrise != null) {
      periods.add(
        SolunarPeriod(
          start: moonrise.subtract(const Duration(minutes: 30)),
          end: moonrise.add(const Duration(minutes: 30)),
          isMajor: false,
        ),
      );
    }
    if (moonset != null) {
      periods.add(
        SolunarPeriod(
          start: moonset.subtract(const Duration(minutes: 30)),
          end: moonset.add(const Duration(minutes: 30)),
          isMajor: false,
        ),
      );
    }

    periods.sort((a, b) => a.start.compareTo(b.start));
    return periods;
  }

  static DateTime _interpolateCrossing(
    DateTime t0,
    DateTime t1,
    double a0,
    double a1,
  ) {
    final denom = a0 - a1;
    if (denom.abs() < 1e-9) {
      return t1;
    }
    final f = a0 / denom;
    final micros = (t1.microsecondsSinceEpoch - t0.microsecondsSinceEpoch) *
        f.clamp(0.0, 1.0);
    return DateTime.fromMicrosecondsSinceEpoch(
      (t0.microsecondsSinceEpoch + micros.round()).clamp(
        t0.microsecondsSinceEpoch,
        t1.microsecondsSinceEpoch,
      ),
      isUtc: true,
    );
  }

  static bool _inPeriod(SolunarPeriod p, DateTime instantUtc) {
    return !instantUtc.isBefore(p.start) && instantUtc.isBefore(p.end);
  }

  static bool isInSolunarPeriod(DateTime now) {
    final cal = istanbulCalendarDate(now);
    final prev = cal.subtract(const Duration(days: 1));
    for (final day in [prev, cal]) {
      for (final p in getSolunarPeriods(day)) {
        if (_inPeriod(p, now.toUtc())) {
          return true;
        }
      }
    }
    return false;
  }

  static bool isInMajorPeriod(DateTime now) {
    final cal = istanbulCalendarDate(now);
    final prev = cal.subtract(const Duration(days: 1));
    for (final day in [prev, cal]) {
      for (final p in getSolunarPeriods(day)) {
        if (p.isMajor && _inPeriod(p, now.toUtc())) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Solunar av penceresi — [start],[end] UTC, yarı açık [start, end).
class SolunarPeriod {
  final DateTime start;
  final DateTime end;
  final bool isMajor;

  const SolunarPeriod({
    required this.start,
    required this.end,
    required this.isMajor,
  });
}
