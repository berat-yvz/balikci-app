import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/time_utils.dart';

void main() {
  group('timeAgo — zaman formatı', () {
    test('30 saniye önce → "Az önce"', () {
      final dt = DateTime.now().subtract(const Duration(seconds: 30));
      expect(timeAgo(dt), 'Az önce');
    });

    test('0 saniye önce → "Az önce"', () {
      final dt = DateTime.now().subtract(const Duration(seconds: 0));
      expect(timeAgo(dt), 'Az önce');
    });

    test('45 dakika önce → "45 dakika önce"', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 45));
      expect(timeAgo(dt), '45 dakika önce');
    });

    test('1 dakika önce → "1 dakika önce"', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 1));
      expect(timeAgo(dt), '1 dakika önce');
    });

    test('59 dakika önce → "59 dakika önce"', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 59));
      expect(timeAgo(dt), '59 dakika önce');
    });

    test('3 saat önce → "3 saat önce"', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      expect(timeAgo(dt), '3 saat önce');
    });

    test('23 saat önce → "23 saat önce"', () {
      final dt = DateTime.now().subtract(const Duration(hours: 23));
      expect(timeAgo(dt), '23 saat önce');
    });

    test('2 gün önce → "2 gün önce"', () {
      final dt = DateTime.now().subtract(const Duration(days: 2));
      expect(timeAgo(dt), '2 gün önce');
    });

    test('6 gün önce → "6 gün önce"', () {
      final dt = DateTime.now().subtract(const Duration(days: 6));
      expect(timeAgo(dt), '6 gün önce');
    });

    test('8 gün önce → "dd Aya" formatında tarih döner', () {
      final dt = DateTime.now().subtract(const Duration(days: 8));
      final result = timeAgo(dt);
      // "3 Nis" gibi bir format bekliyoruz — sayı ve ayın kısaltması
      expect(result.contains(' '), isTrue, reason: 'Boşluk içermeli: "$result"');
      expect(result.length, greaterThan(3));
    });

    test('1 Nisan 2026 → "1 Nis" formatı', () {
      final dt = DateTime(2026, 4, 1);
      final result = timeAgo(dt);
      expect(result, contains('Nis'));
      expect(result, contains('1'));
    });

    test('Türkçe ay kısaltmaları — tüm aylar doğru', () {
      const expected = [
        'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
      ];
      for (var i = 1; i <= 12; i++) {
        // 2020 yılı — tüm tarihler bugünden uzak
        final dt = DateTime(2020, i, 15);
        expect(timeAgo(dt), contains(expected[i - 1]),
            reason: 'Ay $i için "${expected[i - 1]}" beklendi');
      }
    });
  });
}
