import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/score_utils.dart';

void main() {
  group('ScoreUtils.rankFromScore', () {
    test('0 puan → acemi', () {
      expect(ScoreUtils.rankFromScore(0), 'acemi');
    });

    test('499 puan → acemi', () {
      expect(ScoreUtils.rankFromScore(499), 'acemi');
    });

    test('500 puan → olta_kurdu', () {
      expect(ScoreUtils.rankFromScore(500), 'olta_kurdu');
    });

    test('1999 puan → olta_kurdu', () {
      expect(ScoreUtils.rankFromScore(1999), 'olta_kurdu');
    });

    test('2000 puan → usta', () {
      expect(ScoreUtils.rankFromScore(2000), 'usta');
    });

    test('4999 puan → usta', () {
      expect(ScoreUtils.rankFromScore(4999), 'usta');
    });

    test('5000 puan → deniz_reisi', () {
      expect(ScoreUtils.rankFromScore(5000), 'deniz_reisi');
    });

    test('10000 puan → deniz_reisi', () {
      expect(ScoreUtils.rankFromScore(10000), 'deniz_reisi');
    });
  });

  group('ScoreUtils.pointsToNextRank', () {
    test('0 puan → 500 gerekli', () {
      expect(ScoreUtils.pointsToNextRank(0), 500);
    });

    test('200 puan → 300 gerekli (olta_kurdu için)', () {
      expect(ScoreUtils.pointsToNextRank(200), 300);
    });

    test('500 puan → 1500 gerekli (usta için)', () {
      expect(ScoreUtils.pointsToNextRank(500), 1500);
    });

    test('2000 puan → 3000 gerekli (deniz_reisi için)', () {
      expect(ScoreUtils.pointsToNextRank(2000), 3000);
    });

    test('5000 puan → 0 (max rütbe)', () {
      expect(ScoreUtils.pointsToNextRank(5000), 0);
    });

    test('9999 puan → 0 (max rütbede)', () {
      expect(ScoreUtils.pointsToNextRank(9999), 0);
    });
  });

  group('ScoreUtils.rankEmoji', () {
    test('acemi → hook emoji', () {
      expect(ScoreUtils.rankEmoji('acemi'), '🪝');
    });

    test('olta_kurdu → fishing emoji', () {
      expect(ScoreUtils.rankEmoji('olta_kurdu'), '🎣');
    });

    test('usta → anchor emoji', () {
      expect(ScoreUtils.rankEmoji('usta'), '⚓');
    });

    test('deniz_reisi → wave emoji', () {
      expect(ScoreUtils.rankEmoji('deniz_reisi'), '🌊');
    });

    test('bilinmeyen → hook emoji (varsayılan)', () {
      expect(ScoreUtils.rankEmoji('unknown'), '🪝');
    });
  });

  group('ScoreUtils puan sabitleri', () {
    test('public mera paylaşımı +50 puan', () {
      expect(ScoreUtils.spotPublicShare, 50);
    });

    test('yanlış rapor cezası -20 puan', () {
      expect(ScoreUtils.wrongReportPenalty, -20);
    });

    test('doğrulanmış check-in +30 puan', () {
      expect(ScoreUtils.checkinVerified, 30);
    });

    test('doğrulanmamış check-in +15 puan', () {
      expect(ScoreUtils.checkinUnverified, 15);
    });
  });
}
