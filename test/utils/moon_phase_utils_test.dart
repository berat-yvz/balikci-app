import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/moon_phase_utils.dart';

void main() {
  group('MoonPhaseUtils.calculate', () {
    test('referans yeni ay tarihi → yeni ay fazı', () {
      // 6 Ocak 2000 referans yeni ay
      final phase = MoonPhaseUtils.calculate(DateTime.utc(2000, 1, 6, 18, 14));
      expect(phase.phase, closeTo(0.0, 0.001));
      expect(phase.name, 'Yeni Ay');
      expect(phase.emoji, '🌑');
    });

    test('referans + 14.76 gün → dolunay civarı', () {
      final halfCycle = DateTime.utc(2000, 1, 6, 18, 14).add(
        const Duration(hours: 354), // ~14.75 gün
      );
      final phase = MoonPhaseUtils.calculate(halfCycle);
      expect(phase.phase, closeTo(0.5, 0.02));
      expect(phase.name, 'Dolunay');
      expect(phase.emoji, '🌕');
    });

    test('referans + 7.38 gün → ilk dördün civarı', () {
      final quarterCycle = DateTime.utc(2000, 1, 6, 18, 14).add(
        const Duration(hours: 177), // ~7.375 gün
      );
      final phase = MoonPhaseUtils.calculate(quarterCycle);
      expect(phase.phase, closeTo(0.25, 0.02));
    });

    test('phase aralığı her zaman [0,1)', () {
      // 5 yıl ilerisi
      final future = DateTime.now().add(const Duration(days: 1825));
      final phase = MoonPhaseUtils.calculate(future);
      expect(phase.phase, greaterThanOrEqualTo(0.0));
      expect(phase.phase, lessThan(1.0));
    });

    test('parametresiz çağrı bugünkü tarihi kullanır', () {
      final phase = MoonPhaseUtils.calculate();
      expect(phase.phase, greaterThanOrEqualTo(0.0));
      expect(phase.phase, lessThan(1.0));
      expect(phase.name, isNotEmpty);
      expect(phase.emoji, isNotEmpty);
      expect(phase.fishingTip, isNotEmpty);
    });
  });

  group('MoonPhase aydınlanma', () {
    test('yeni ay → aydınlanma sıfıra yakın', () {
      final phase = MoonPhaseUtils.calculate(DateTime.utc(2000, 1, 6, 18, 14));
      expect(phase.illumination, closeTo(0.0, 0.01));
    });

    test('dolunay → aydınlanma bire yakın', () {
      final fullMoon = DateTime.utc(2000, 1, 6, 18, 14).add(
        const Duration(hours: 354),
      );
      final phase = MoonPhaseUtils.calculate(fullMoon);
      expect(phase.illumination, closeTo(1.0, 0.05));
    });

    test('illumination == fullnessPct', () {
      final phase = MoonPhaseUtils.calculate(DateTime.utc(2000, 1, 20));
      expect(phase.fullnessPct, equals(phase.illumination));
    });
  });

  group('MoonPhaseUtils faz isimleri', () {
    final testCases = [
      (0.03, 'Yeni Ay', '🌑'),
      (0.12, 'Hilal', '🌒'),
      (0.25, 'İlk Dördün', '🌓'),
      (0.38, 'Şişen Ay', '🌔'),
      (0.50, 'Dolunay', '🌕'),
      (0.63, 'Azalan Ay', '🌖'),
      (0.75, 'Son Dördün', '🌗'),
      (0.88, 'Eğrilen Ay', '🌘'),
      (0.97, 'Yeni Ay', '🌑'),
    ];

    for (final (phase, expectedName, expectedEmoji) in testCases) {
      test('faz $phase → $expectedName $expectedEmoji', () {
        // Faz değerini doğrudan referans tarihine çevir
        final seconds = (phase * 29.53059 * 86400).round();
        final date = DateTime.utc(2000, 1, 6, 18, 14).add(
          Duration(seconds: seconds),
        );
        final result = MoonPhaseUtils.calculate(date);
        expect(result.name, expectedName);
        expect(result.emoji, expectedEmoji);
      });
    }
  });
}
