import 'dart:convert';
import 'dart:math' as math;

import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/core/utils/moon_phase_calculator.dart';

/// Kural tabanlı balıkçılık skoru — saf Dart, Flutter yok.
class FishingScoreEngine {
  FishingScoreEngine._(this._rules, this._speciesRoot, this._moonRoot);

  final Map<String, dynamic> _rules;
  final Map<String, dynamic> _speciesRoot;
  final Map<String, dynamic> _moonRoot;

  /// JSON stringlerinden motor oluşturur ([rootBundle] yükleme üst katmanda).
  factory FishingScoreEngine.fromJsonStrings(
    String fishingRules,
    String fishSpecies,
    String moonPhaseRules,
  ) {
    return FishingScoreEngine._(
      jsonDecode(fishingRules) as Map<String, dynamic>,
      jsonDecode(fishSpecies) as Map<String, dynamic>,
      jsonDecode(moonPhaseRules) as Map<String, dynamic>,
    );
  }

  FishingScore calculate(
    WeatherModel weather,
    DateTime now,
    double moonIllumination,
  ) {
    final moonIll = moonIllumination.clamp(0.0, 1.0);
    final phaseId = MoonPhaseCalculator.phaseIdForIllumination(moonIll);
    final pressureTrendStr = _computePressureTrend(weather);
    final ctx = _WeatherContext.from(weather, now, pressureTrendStr);

    final hardStops =
        (_rules['hard_stop_rules'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    for (final rule in hardStops) {
      final when = rule['when'] as Map<String, dynamic>? ?? {};
      if (_matchesWhen(when, ctx)) {
        final raw = rule['result_score'];
        final score = _clampInt(
          raw is num ? raw.round() : 0,
          0,
          100,
        );
        final message = rule['message']?.toString() ?? '';
        final summaryKey = rule['summary_key']?.toString();
        final templates = _rules['summary_templates'] as Map<String, dynamic>? ??
            {};
        final summary = _summaryFromHardStop(
          score,
          summaryKey,
          templates,
          message,
        );
        final labelRow = _labelForScore(score);
        return FishingScore(
          score: score,
          label: labelRow.$1,
          labelColor: labelRow.$2,
          summary: summary,
          activeMessages: message.isEmpty ? [] : [message],
          suggestedSpecies: const [],
          pressureTrend: null,
        );
      }
    }

    var score = 50;
    final messages = <_WeightedMessage>[];

    final weatherMods =
        (_rules['weather_score_modifiers'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final mod in weatherMods) {
      final when = mod['when'] as Map<String, dynamic>? ?? {};
      if (!_matchesWhen(when, ctx)) continue;
      final d = mod['score_delta'];
      if (d is num) score += d.round();
      final msg = mod['message']?.toString() ?? '';
      final p = mod['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 50,
          tier: 2,
        ),
      );
    }

    final seasonal =
        (_rules['seasonal_modifiers'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final mod in seasonal) {
      final months = (mod['months'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList();
      if (!months.contains(now.month)) continue;
      final d = mod['score_delta'];
      if (d is num) score += d.round();
      final msg = mod['message']?.toString() ?? '';
      final p = mod['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 30,
          tier: 3,
        ),
      );
    }

    final moonPhases =
        (_moonRoot['phases'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final ph in moonPhases) {
      final minI = (ph['illumination_min'] as num?)?.toDouble() ?? 0;
      final maxI = (ph['illumination_max'] as num?)?.toDouble() ?? 1;
      if (moonIll < minI || moonIll >= maxI) continue;
      final d = ph['base_score_delta'];
      if (d is num) score += d.round();
      final msg = ph['message']?.toString() ?? '';
      final p = ph['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 10,
          tier: 4,
        ),
      );
      break;
    }

    // ── Barometrik trend + fırtına öncesi (basınç + WMO) ────────────────
    final preStormMap = _rules['pre_storm_barometric'] as Map<String, dynamic>?;
    final preStormCodes = (preStormMap?['weather_codes'] as List<dynamic>? ??
            const [])
        .map((e) => (e as num).toInt())
        .toSet();
    final isPreStormBarometric = pressureTrendStr == 'falling_fast' &&
        preStormCodes.contains(ctx.weatherCode);

    if (isPreStormBarometric) {
      final d = preStormMap?['score_delta'];
      if (d is num) {
        score += d.round();
      }
      final msg = preStormMap?['message']?.toString() ?? '';
      final p = preStormMap?['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 78,
          tier: 2,
        ),
      );
    }

    final baroRoot = _rules['barometric_pressure_rules'] as Map<String, dynamic>?;
    final baroRules =
        (baroRoot?['rules'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final rule in baroRules) {
      final when = rule['when'] as Map<String, dynamic>? ?? {};
      if (isPreStormBarometric && when['pressure_trend'] == 'falling_fast') {
        continue;
      }
      if (!_matchesWhen(when, ctx)) {
        continue;
      }
      final d = rule['score_delta'];
      if (d is num) {
        score += d.round();
      }
      final msg = rule['message']?.toString() ?? '';
      final p = rule['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 50,
          tier: 2,
        ),
      );
    }

    // ── Solunar (bonus: moon JSON; mesaj/öncelik: moon + fishing yedek) ───
    final guide = _moonRoot['solunar_calculation_guide'] as Map<String, dynamic>?;
    final solBonuses = guide?['score_bonuses'] as Map<String, dynamic>?;
    final majorBonus =
        (solBonuses?['major_period_active_bonus'] as num?)?.round() ?? 12;
    final minorBonus =
        (solBonuses?['minor_period_active_bonus'] as num?)?.round() ?? 6;
    final solunarRulesRoot = _rules['solunar_rules'] as Map<String, dynamic>?;
    final majorP =
        (solunarRulesRoot?['major_period_priority'] as num?)?.round() ?? 65;
    final minorP =
        (solunarRulesRoot?['minor_period_priority'] as num?)?.round() ?? 38;
    final majorSolMsg = solBonuses?['major_period_message']?.toString() ??
        solunarRulesRoot?['major_period_message']?.toString() ??
        '✓ Solunar ana periyot: av zamanı!';
    final minorSolMsg = solBonuses?['minor_period_message']?.toString() ??
        solunarRulesRoot?['minor_period_message']?.toString() ??
        '✓ Solunar yan periyot.';

    if (MoonPhaseCalculator.isInMajorPeriod(now)) {
      score += majorBonus;
      messages.add(
        _WeightedMessage(
          message: majorSolMsg,
          priority: majorP,
          tier: 2,
        ),
      );
    } else if (MoonPhaseCalculator.isInSolunarPeriod(now)) {
      score += minorBonus;
      messages.add(
        _WeightedMessage(
          message: minorSolMsg,
          priority: minorP,
          tier: 2,
        ),
      );
    }

    // ── İstanbul Boğazı ─────────────────────────────────────────────────
    final istRules =
        _rules['istanbul_specific_rules'] as Map<String, dynamic>?;
    final bosphorus = (istRules?['bosphorus_current_rules'] as List<dynamic>? ??
            const [])
        .cast<Map<String, dynamic>>();
    for (final rule in bosphorus) {
      final when = rule['when'] as Map<String, dynamic>? ?? {};
      if (!_matchesWhen(when, ctx)) {
        continue;
      }
      final d = rule['score_delta'];
      if (d is num) {
        score += d.round();
      }
      final msg = rule['message']?.toString() ?? '';
      final p = rule['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 45,
          tier: 2,
        ),
      );
    }

    // ── Fırtına öncesi/sonrası (ileri sprint; bayraklar şimdilik false) ───
    final ppsRoot = _rules['pre_post_storm_rules'] as Map<String, dynamic>?;
    final ppsRules =
        (ppsRoot?['rules'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final rule in ppsRules) {
      final when = rule['when'] as Map<String, dynamic>? ?? {};
      if (!_matchesWhen(when, ctx)) {
        continue;
      }
      final d = rule['score_delta'];
      if (d is num) {
        score += d.round();
      }
      final msg = rule['message']?.toString() ?? '';
      final p = rule['priority'];
      messages.add(
        _WeightedMessage(
          message: msg,
          priority: p is num ? p.round() : 50,
          tier: 2,
        ),
      );
    }

    score = _clampInt(score, 0, 100);
    messages.sort((a, b) {
      final c = b.priority.compareTo(a.priority);
      if (c != 0) return c;
      return a.tier.compareTo(b.tier);
    });

    final topMessages = <String>[];
    for (final m in messages) {
      if (m.message.isEmpty) continue;
      if (topMessages.length >= 3) break;
      if (!topMessages.contains(m.message)) topMessages.add(m.message);
    }

    final templates = _rules['summary_templates'] as Map<String, dynamic>? ?? {};
    final summary = _buildSummary(score, topMessages, templates);

    final labelRow = _labelForScore(score);
    final species = _rankSpecies(weather, now, phaseId);

    return FishingScore(
      score: score,
      label: labelRow.$1,
      labelColor: labelRow.$2,
      summary: summary,
      activeMessages: topMessages,
      suggestedSpecies: species,
      pressureTrend: pressureTrendStr,
    );
  }

  /// `pressureHpa` ve `pressureHpa3hAgo` farkına göre trend anahtarı; veri yoksa null.
  static String? _computePressureTrend(WeatherModel w) {
    final now = w.pressureHpa;
    final ago = w.pressureHpa3hAgo;
    if (now == null || ago == null) {
      return null;
    }
    final diff = now - ago;
    if (diff > 3.0) {
      return 'rising_fast';
    }
    if (diff > 1.5) {
      return 'rising';
    }
    if (diff < -3.0) {
      return 'falling_fast';
    }
    if (diff < -1.5) {
      return 'falling';
    }
    return 'stable';
  }

  (String, String) _labelForScore(int score) {
    final labels =
        (_rules['score_labels'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    final sorted = [...labels]..sort((a, b) {
        final ma = (a['min_score'] as num?)?.toInt() ?? 0;
        final mb = (b['min_score'] as num?)?.toInt() ?? 0;
        return mb.compareTo(ma);
      });
    for (final row in sorted) {
      final minS = (row['min_score'] as num?)?.toInt() ?? 0;
      if (score >= minS) {
        return (
          row['label']?.toString() ?? 'Orta',
          row['label_color']?.toString() ?? 'amber',
        );
      }
    }
    return ('Orta', 'amber');
  }

  String _summaryFromHardStop(
    int score,
    String? summaryKey,
    Map<String, dynamic> templates,
    String fallbackMessage,
  ) {
    if (summaryKey != null && templates.containsKey(summaryKey)) {
      return _trim(
        templates[summaryKey]!.toString(),
        60,
      );
    }
    if (fallbackMessage.isNotEmpty) {
      return _trim(_stripLeadingIcon(fallbackMessage), 60);
    }
    return _trim(
      score >= 40
          ? (templates['default_neutral']?.toString() ?? 'Koşullar zor.')
          : (templates['default_negative']?.toString() ?? 'Koşullar zor.'),
      60,
    );
  }

  String _buildSummary(
    int score,
    List<String> topMessages,
    Map<String, dynamic> templates,
  ) {
    if (topMessages.isNotEmpty) {
      return _trim(_stripLeadingIcon(topMessages.first), 60);
    }
    if (score >= 70) {
      return _trim(
        templates['default_positive']?.toString() ?? 'Koşullar uygun.',
        60,
      );
    }
    if (score >= 45) {
      return _trim(
        templates['default_neutral']?.toString() ?? 'Koşullar ortalama.',
        60,
      );
    }
    return _trim(
      templates['default_negative']?.toString() ?? 'Koşullar zorlayıcı.',
      60,
    );
  }

  List<FishSpeciesTip> _rankSpecies(
    WeatherModel weather,
    DateTime now,
    String phaseId,
  ) {
    final list =
        (_speciesRoot['species'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    final wind = weather.windKmh;
    final wave = weather.waveHeight ?? 0.0;

    final ranked = <MapEntry<int, FishSpeciesTip>>[];

    for (final s in list) {
      final id = s['id']?.toString() ?? '';
      final name = s['name']?.toString() ?? id;
      final months = (s['active_months'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList();
      final inSeason = months.contains(now.month);
      final wMax = (s['optimal_wind_max'] as num?)?.toDouble() ?? 999;
      final waveMax = (s['optimal_wave_max'] as num?)?.toDouble() ?? 999;
      final condOk = wind <= wMax && wave <= waveMax;

      final bonusMap = s['moon_phase_bonus'] as Map<String, dynamic>?;
      var moonBonus = 0;
      if (bonusMap != null) {
        final v = bonusMap[phaseId];
        if (v is num) {
          moonBonus = v.round();
        } else if (bonusMap['default'] is num) {
          moonBonus = (bonusMap['default'] as num).round();
        }
      }

      var pts = moonBonus;
      if (inSeason) {
        pts += 50;
      } else {
        pts += 8;
      }
      if (condOk) {
        pts += 40;
      } else {
        pts += 12;
      }

      final optSstMin = (s['optimal_sst_min'] as num?)?.toDouble();
      final optSstMax = (s['optimal_sst_max'] as num?)?.toDouble();
      final sst = weather.seaSurfaceTemperature;
      if (sst != null && optSstMin != null && optSstMax != null) {
        if (sst >= optSstMin && sst <= optSstMax) {
          pts += 15;
        } else if (sst < optSstMin - 4 || sst > optSstMax + 4) {
          pts -= 20;
        }
      }

      ranked.add(
        MapEntry(
          pts,
          FishSpeciesTip(
            id: id,
            name: name,
            isInSeason: inSeason,
            tip: s['tip']?.toString(),
          ),
        ),
      );
    }

    ranked.sort((a, b) => b.key.compareTo(a.key));
    return ranked.take(3).map((e) => e.value).toList();
  }

  bool _matchesWhen(Map<String, dynamic> when, _WeatherContext ctx) {
    for (final e in when.entries) {
      if (!_matchOne(e.key, e.value, ctx)) return false;
    }
    return true;
  }

  bool _matchOne(String key, Object? value, _WeatherContext ctx) {
    switch (key) {
      case 'windspeed_kmh_min':
        return value is num && ctx.windKmh >= value.toDouble();
      case 'windspeed_kmh_max':
        return value is num && ctx.windKmh <= value.toDouble();
      case 'wave_height_m_min':
        return value is num && ctx.waveM >= value.toDouble();
      case 'wave_height_m_max':
        return value is num && ctx.waveM <= value.toDouble();
      case 'sea_surface_temp_c_min':
        if (ctx.seaC == null) return false;
        return value is num && ctx.seaC! >= value.toDouble();
      case 'sea_surface_temp_c_max':
        if (ctx.seaC == null) return false;
        return value is num && ctx.seaC! <= value.toDouble();
      case 'temperature_c_min':
        return value is num && ctx.tempC >= value.toDouble();
      case 'temperature_c_max':
        return value is num && ctx.tempC <= value.toDouble();
      case 'precipitation_mm_h_min':
        return value is num && ctx.precipMm >= value.toDouble();
      case 'precipitation_mm_h_max':
        return value is num && ctx.precipMm <= value.toDouble();
      case 'weather_code_in':
        if (value is! List) return false;
        final codes = value.map((e) => (e as num).toInt()).toSet();
        return codes.contains(ctx.weatherCode);
      case 'weather_code_not_in':
        if (value is! List) return false;
        final codes = value.map((e) => (e as num).toInt()).toSet();
        return !codes.contains(ctx.weatherCode);
      case 'wind_direction_deg_min':
        if (ctx.windDir == null) return false;
        return value is num && ctx.windDir! >= value.toDouble();
      case 'wind_direction_deg_max':
        if (ctx.windDir == null) return false;
        return value is num && ctx.windDir! <= value.toDouble();
      case 'is_golden_hour':
        return value == true && ctx.isGoldenHour;
      case 'is_night':
        return value == true && ctx.isNight;
      case 'month_in':
        if (value is! List) {
          return false;
        }
        final months = value.map((e) => (e as num).toInt()).toList();
        return months.contains(ctx.month);
      case 'pressure_trend':
        return value != null && value.toString() == ctx.pressureTrend;
      case 'pressure_hpa_min':
        if (ctx.pressureHpa == null) {
          return false;
        }
        return value is num && ctx.pressureHpa! >= value.toDouble();
      case 'pressure_hpa_max':
        if (ctx.pressureHpa == null) {
          return false;
        }
        return value is num && ctx.pressureHpa! <= value.toDouble();
      case 'is_pre_storm_window':
        return value == true && ctx.isPreStormWindow;
      case 'is_post_storm_recovery_24h':
        return value == true && ctx.isPostStormRecovery24h;
      case 'is_post_storm_recovery_48h':
        return value == true && ctx.isPostStormRecovery48h;
      default:
        return false;
    }
  }

  static int _clampInt(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  static String _trim(String s, int max) {
    if (s.length <= max) return s;
    if (max <= 1) return '…';
    return '${s.substring(0, max - 1)}…';
  }

  static String _stripLeadingIcon(String s) {
    return s.replaceFirst(RegExp(r'^[✓⚠️ℹ️]+\s*'), '').trim();
  }
}

class _WeightedMessage {
  final String message;
  final int priority;
  /// 2=weather, 3=seasonal, 4=moon (hard stop ayrı)
  final int tier;

  _WeightedMessage({
    required this.message,
    required this.priority,
    required this.tier,
  });
}

class _WeatherContext {
  _WeatherContext({
    required this.windKmh,
    required this.waveM,
    required this.seaC,
    required this.tempC,
    required this.precipMm,
    required this.weatherCode,
    required this.windDir,
    required this.isGoldenHour,
    required this.isNight,
    required this.month,
    required this.pressureTrend,
    required this.pressureHpa,
    required this.isPreStormWindow,
    required this.isPostStormRecovery24h,
    required this.isPostStormRecovery48h,
  });

  final double windKmh;
  final double waveM;
  final double? seaC;
  final double tempC;
  final double precipMm;
  final int weatherCode;
  final int? windDir;
  final bool isGoldenHour;
  final bool isNight;
  final int month;
  final String? pressureTrend;
  final double? pressureHpa;
  final bool isPreStormWindow;
  final bool isPostStormRecovery24h;
  final bool isPostStormRecovery48h;

  factory _WeatherContext.from(
    WeatherModel w,
    DateTime nowLocal,
    String? pressureTrend,
  ) {
    final code = w.weatherCode ?? 0;
    final windDir = w.windDirection;
    return _WeatherContext(
      windKmh: w.windKmh,
      waveM: w.waveHeight ?? 0,
      seaC: w.seaSurfaceTemperature,
      tempC: w.tempCelsius,
      precipMm: w.precipitation ?? 0,
      weatherCode: code,
      windDir: windDir,
      isGoldenHour: _isGoldenHourIstanbul(nowLocal),
      isNight: _isNight(nowLocal),
      month: nowLocal.month,
      pressureTrend: pressureTrend,
      pressureHpa: w.pressureHpa,
      isPreStormWindow: false,
      isPostStormRecovery24h: false,
      isPostStormRecovery48h: false,
    );
  }

  /// Gün doğumu/batımı ±90 dk — İstanbul için mevsimsel basit interpolasyon.
  static bool _isGoldenHourIstanbul(DateTime local) {
    final doy = _dayOfYear(local);
    final t = math.cos(2 * math.pi * (doy - 172) / 365.25);
    final sunriseH = 7.5 - 2.0 * ((t + 1) / 2);
    final sunsetH = 17.5 + 3.5 * ((t + 1) / 2);
    final minutes = local.hour * 60 + local.minute;
    final sr = (sunriseH * 60).round();
    final ss = (sunsetH * 60).round();
    return (minutes - sr).abs() <= 90 || (minutes - ss).abs() <= 90;
  }

  static bool _isNight(DateTime local) {
    final h = local.hour;
    return h >= 22 || h < 4;
  }

  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }
}
