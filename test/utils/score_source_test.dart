import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/services/score_service.dart';

void main() {
  group('ScoreSource — enum değerleri', () {
    test('checkinVerified → "checkin_verified"', () {
      expect(ScoreSource.checkinVerified.value, 'checkin_verified');
    });

    test('checkinUnverified → "checkin_unverified"', () {
      expect(ScoreSource.checkinUnverified.value, 'checkin_unverified');
    });

    test('correctVote → "correct_vote"', () {
      expect(ScoreSource.correctVote.value, 'correct_vote');
    });

    test('wrongReport → "wrong_report"', () {
      expect(ScoreSource.wrongReport.value, 'wrong_report');
    });

    test('fishLogPublic → "fish_log_public"', () {
      expect(ScoreSource.fishLogPublic.value, 'fish_log_public');
    });

    test('releaseExif → "release_exif"', () {
      expect(ScoreSource.releaseExif.value, 'release_exif');
    });

    test('spotPublic → "spot_public"', () {
      expect(ScoreSource.spotPublic.value, 'spot_public');
    });

    test('tüm kaynak tipleri farklı string değerlere sahip', () {
      final values = ScoreSource.values.map((s) => s.value).toList();
      expect(values.length, values.toSet().length);
    });

    test('ScoreSource.values toplamda 7 kayıt', () {
      expect(ScoreSource.values.length, 7);
    });
  });
}
