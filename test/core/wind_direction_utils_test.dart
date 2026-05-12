import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/core/utils/wind_direction_utils.dart';

void main() {
  group('formatWindDirectionTurkish', () {
    test('164° → Güney', () {
      expect(formatWindDirectionTurkish(164), 'Güney · 164°');
    });

    test('225° → Güneybatı', () {
      expect(formatWindDirectionTurkish(225), 'Güneybatı · 225°');
    });

    test('null → —', () {
      expect(formatWindDirectionTurkish(null), '—');
    });

    test('negatif derece normalize', () {
      expect(formatWindDirectionTurkish(-90), 'Batı · 270°');
    });
  });

  group('isSoutherlyWindCoastalAdvisory', () {
    test('164° güney dilimi içinde', () {
      expect(isSoutherlyWindCoastalAdvisory(164), isTrue);
    });

    test('90° doğu — uyarı yok', () {
      expect(isSoutherlyWindCoastalAdvisory(90), isFalse);
    });
  });
}
