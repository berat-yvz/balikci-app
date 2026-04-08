import 'dart:math' as math;

/// Ay fazı hesaplama — API gerektirmez, saf matematiksel hesaplama.
///
/// Algoritma: bilinen referans yeni ay tarihinden itibaren
/// ortalama ay döngüsü (29.53059 gün) kullanılır.
class MoonPhaseUtils {
  MoonPhaseUtils._();

  /// Ortalama ay döngüsü (gün).
  static const double _synodicMonth = 29.53059;

  /// Referans yeni ay — 6 Ocak 2000, 18:14 UTC (J2000.0 civarı)
  static final DateTime _referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  /// Verilen tarih için [MoonPhase] döner.
  static MoonPhase calculate([DateTime? date]) {
    final now = date ?? DateTime.now();
    final daysSinceRef = now.difference(_referenceNewMoon).inSeconds / 86400.0;
    final phase = (daysSinceRef % _synodicMonth) / _synodicMonth;
    // [0,1) aralığı: 0=yeni ay, 0.25=ilk dördün, 0.5=dolunay, 0.75=son dördün

    final illumination = _illumination(phase);

    return MoonPhase(
      phase: phase,
      illumination: illumination,
      name: _name(phase),
      emoji: _emoji(phase),
      fishingTip: _fishingTip(phase),
    );
  }

  /// Aydınlanma oranı (0–1) — görsel doluluk.
  static double _illumination(double phase) {
    // cos fonksiyonuna dayalı yaklaşım
    return (1 - math.cos(2 * math.pi * phase)) / 2;
  }

  static String _name(double p) {
    if (p < 0.0625) return 'Yeni Ay';
    if (p < 0.1875) return 'Hilal';
    if (p < 0.3125) return 'İlk Dördün';
    if (p < 0.4375) return 'Şişen Ay';
    if (p < 0.5625) return 'Dolunay';
    if (p < 0.6875) return 'Azalan Ay';
    if (p < 0.8125) return 'Son Dördün';
    if (p < 0.9375) return 'Eğrilen Ay';
    return 'Yeni Ay';
  }

  static String _emoji(double p) {
    if (p < 0.0625) return '🌑';
    if (p < 0.1875) return '🌒';
    if (p < 0.3125) return '🌓';
    if (p < 0.4375) return '🌔';
    if (p < 0.5625) return '🌕';
    if (p < 0.6875) return '🌖';
    if (p < 0.8125) return '🌗';
    if (p < 0.9375) return '🌘';
    return '🌑';
  }

  /// Balıkçılık ipucu — Türk balıkçı kültürüne dayalı.
  static String _fishingTip(double p) {
    if (p < 0.0625 || p >= 0.9375) {
      return 'Yeni ay dönemi. Balıklar derine iner, gece avı zayıf.';
    }
    if (p < 0.1875) {
      return 'Hilal. Balık aktivitesi artıyor, akşam saatleri iyi.';
    }
    if (p < 0.3125) {
      return 'İlk dördün. Orta aktivite, sabah ve akşam saatleri tercih et.';
    }
    if (p < 0.4375) {
      return 'Dolunaya yaklaşılıyor. Aktivite artıyor, gece avı verimli.';
    }
    if (p < 0.5625) {
      return 'Dolunay! En yüksek aktivite. Gece ve şafak saatleri altın değer.';
    }
    if (p < 0.6875) {
      return 'Dolunay sonrası. Aktivite hâlâ yüksek, sabah erken çıkmaya değer.';
    }
    if (p < 0.8125) {
      return 'Son dördün. Aktivite azalıyor, gündüz balıkçılığı daha iyi.';
    }
    return 'Ay kararıyor. Balıklar yüzeye çıkmayı azaltır.';
  }
}

class MoonPhase {
  /// 0 (yeni ay) — 1 (tam döngü) arasında fazı temsil eder.
  final double phase;

  /// Aydınlanma oranı (0=karanlık, 1=tam dolu).
  final double illumination;

  final String name;
  final String emoji;
  final String fishingTip;

  const MoonPhase({
    required this.phase,
    required this.illumination,
    required this.name,
    required this.emoji,
    required this.fishingTip,
  });

  /// Dolunaya yakınlık (0=yeni ay, 1=dolunay).
  double get fullnessPct => illumination;
}
