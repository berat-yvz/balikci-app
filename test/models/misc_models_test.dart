import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/notification_model.dart';

void main() {
  // ─── NotificationModel ───────────────────────────────────────────────────

  group('NotificationModel.fromJson', () {
    final baseJson = {
      'id': 'notif-1',
      'user_id': 'user-1',
      'type': 'checkin',
      'title': "Mera'da balık var!",
      'body': "Bebek Koyu'nda yeni check-in",
      'data_json': {'spot_id': 'spot-1', 'type': 'checkin'},
      'read': false,
      'created_at': '2025-03-01T09:00:00.000Z',
    };

    test('tam veriyle parse edilir', () {
      final notif = NotificationModel.fromJson(baseJson);
      expect(notif.id, 'notif-1');
      expect(notif.userId, 'user-1');
      expect(notif.type, 'checkin');
      expect(notif.title, "Mera'da balık var!");
      expect(notif.read, isFalse);
      expect(notif.data['spot_id'], 'spot-1');
      expect(notif.createdAt.year, 2025);
    });

    test('data_json null → boş map', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['data_json'] = null;
      final notif = NotificationModel.fromJson(json);
      expect(notif.data, isEmpty);
    });

    test('read null → false varsayılan', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['read'] = null;
      final notif = NotificationModel.fromJson(json);
      expect(notif.read, isFalse);
    });

    test('read 1 veya "true" → okundu', () {
      final j1 = Map<String, dynamic>.from(baseJson)..['read'] = 1;
      expect(NotificationModel.fromJson(j1).read, isTrue);
      final j2 = Map<String, dynamic>.from(baseJson)..['read'] = 'true';
      expect(NotificationModel.fromJson(j2).read, isTrue);
    });
  });
}
