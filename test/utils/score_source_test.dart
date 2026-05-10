import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/services/score_service.dart';

void main() {
  group('ScoreSource — enum değerleri', () {
    test('checkinUnverified → "checkin_unverified"', () {
      expect(ScoreSource.checkinUnverified.value, 'checkin_unverified');
    });

    test('correctVote → "correct_vote"', () {
      expect(ScoreSource.correctVote.value, 'correct_vote');
    });

    test('wrongReport → "wrong_report"', () {
      expect(ScoreSource.wrongReport.value, 'wrong_report');
    });

    test('spotPublic → "spot_public"', () {
      expect(ScoreSource.spotPublic.value, 'spot_public');
    });

    test('spotFriends → "spot_friends"', () {
      expect(ScoreSource.spotFriends.value, 'spot_friends');
    });

    test('spotPrivate → "spot_private"', () {
      expect(ScoreSource.spotPrivate.value, 'spot_private');
    });

    test('postShared → "post_share"', () {
      expect(ScoreSource.postShared.value, 'post_share');
    });

    test('postLiked → "post_liked"', () {
      expect(ScoreSource.postLiked.value, 'post_liked');
    });

    test('postComment → "post_comment"', () {
      expect(ScoreSource.postComment.value, 'post_comment');
    });

    test('tüm kaynak tipleri farklı string değerlere sahip', () {
      final values = ScoreSource.values.map((s) => s.value).toList();
      expect(values.length, values.toSet().length);
    });

    test('ScoreSource.values toplamda 9 kayıt', () {
      expect(ScoreSource.values.length, 9);
    });
  });
}
