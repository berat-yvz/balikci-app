import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/knot_model.dart';
import 'package:balikci_app/data/models/notification_model.dart';
import 'package:balikci_app/data/models/fish_log_model.dart';

void main() {
  // ─── KnotModel ────────────────────────────────────────────────────────────

  group('KnotModel.fromJson', () {
    final baseJson = {
      'id': 'knot-1',
      'title': 'Kanca Düğümü',
      'category': 'temel',
      'difficulty': 2,
      'use_cases': ['deniz', 'göl'],
      'steps': ['İpi halka yap', 'Ucunu geçir', 'Sık'],
    };

    test('tam veriyle parse edilir', () {
      final knot = KnotModel.fromJson(baseJson);
      expect(knot.id, 'knot-1');
      expect(knot.title, 'Kanca Düğümü');
      expect(knot.category, 'temel');
      expect(knot.difficulty, 2);
      expect(knot.useCases, ['deniz', 'göl']);
      expect(knot.steps.length, 3);
    });

    test('eksik alanlar için varsayılanlar', () {
      final knot = KnotModel.fromJson({});
      expect(knot.id, '');
      expect(knot.title, '');
      expect(knot.difficulty, 1);
      expect(knot.useCases, isEmpty);
      expect(knot.steps, isEmpty);
    });

    test('steps liste olarak parse edilir', () {
      final knot = KnotModel.fromJson(baseJson);
      expect(knot.steps, isA<List<String>>());
    });
  });

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

  // ─── FishLogModel ────────────────────────────────────────────────────────

  group('FishLogModel.fromJson', () {
    final baseJson = {
      'id': 'log-1',
      'user_id': 'user-1',
      'spot_id': 'spot-1',
      'species': 'Lüfer',
      'weight': 1.5,
      'length': 35.0,
      'photo_url': null,
      'weather_snapshot': null,
      'is_private': false,
      'released': false,
      'created_at': '2025-02-15T07:30:00.000Z',
    };

    test('tam veriyle parse edilir', () {
      final log = FishLogModel.fromJson(baseJson);
      expect(log.id, 'log-1');
      expect(log.userId, 'user-1');
      expect(log.spotId, 'spot-1');
      expect(log.species, 'Lüfer');
      expect(log.weight, closeTo(1.5, 0.001));
      expect(log.length, closeTo(35.0, 0.001));
      expect(log.isPrivate, isFalse);
      expect(log.released, isFalse);
    });

    test('opsiyonel alanlar null olabilir', () {
      final json = Map<String, dynamic>.from(baseJson);
      json.remove('spot_id');
      json.remove('weight');
      json.remove('length');
      final log = FishLogModel.fromJson(json);
      expect(log.spotId, isNull);
      expect(log.weight, isNull);
      expect(log.length, isNull);
    });

    test('released true → sürdürülebilirlik işaretlendi', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['released'] = true;
      final log = FishLogModel.fromJson(json);
      expect(log.released, isTrue);
    });

    test('toJson round-trip', () {
      final original = FishLogModel.fromJson(baseJson);
      final json = original.toJson();
      final restored = FishLogModel.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.species, original.species);
      expect(restored.weight, original.weight);
      expect(restored.released, original.released);
    });

    test('toJson doğru key isimleri kullanır', () {
      final log = FishLogModel.fromJson(baseJson);
      final json = log.toJson();
      expect(json.containsKey('user_id'), isTrue);
      expect(json.containsKey('spot_id'), isTrue);
      expect(json.containsKey('is_private'), isTrue);
      expect(json.containsKey('released'), isTrue);
    });
  });
}
