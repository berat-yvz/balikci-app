import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/notification_routing.dart';

void main() {
  group('notification_routing', () {
    test('profileUserIdFromNotificationData önce follower_id okur', () {
      expect(
        profileUserIdFromNotificationData({
          'follower_id': 'aaa',
          'from_user_id': 'bbb',
        }),
        'aaa',
      );
    });

    test('profileUserIdFromNotificationData from_user_id yedek', () {
      expect(
        profileUserIdFromNotificationData({'from_user_id': 'ccc'}),
        'ccc',
      );
    });

    test('notificationTypeOpensFollowProfile follow ve follow_request', () {
      expect(notificationTypeOpensFollowProfile('follow'), true);
      expect(notificationTypeOpensFollowProfile('follow_request'), true);
      expect(notificationTypeOpensFollowProfile('rank_up'), false);
      expect(notificationTypeOpensFollowProfile('checkin'), false);
    });
  });
}
