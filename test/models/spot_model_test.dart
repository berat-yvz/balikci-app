import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/spot_model.dart';

void main() {
  final baseJson = {
    'id': 'spot-1',
    'user_id': 'user-1',
    'name': 'Bebek Koyu',
    'lat': 41.0773,
    'lng': 29.0454,
    'type': 'kıyı',
    'privacy_level': 'public',
    'description': 'Güzel bir koy',
    'verified': true,
    'muhtar_id': 'muhtar-1',
    'created_at': '2025-01-15T10:00:00.000Z',
  };

  group('SpotModel.fromJson', () {
    test('tam veriyle parse edilir', () {
      final spot = SpotModel.fromJson(baseJson);
      expect(spot.id, 'spot-1');
      expect(spot.userId, 'user-1');
      expect(spot.name, 'Bebek Koyu');
      expect(spot.lat, closeTo(41.0773, 0.0001));
      expect(spot.lng, closeTo(29.0454, 0.0001));
      expect(spot.type, 'kıyı');
      expect(spot.privacyLevel, 'public');
      expect(spot.description, 'Güzel bir koy');
      expect(spot.verified, isTrue);
      expect(spot.muhtarId, 'muhtar-1');
    });

    test('eksik alanlar için varsayılanlar uygulanır', () {
      final minimal = {
        'id': 'spot-2',
        'user_id': 'user-2',
        'name': 'Test Mera',
        'lat': 40.0,
        'lng': 29.0,
        'created_at': '2025-01-01T00:00:00.000Z',
      };
      final spot = SpotModel.fromJson(minimal);
      expect(spot.privacyLevel, 'public');
      expect(spot.verified, isFalse);
      expect(spot.muhtarId, isNull);
      expect(spot.type, isNull);
      expect(spot.description, isNull);
    });

    test('lat/lng integer olarak gelse de double\'a çevrilir', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['lat'] = 41;
      json['lng'] = 29;
      final spot = SpotModel.fromJson(json);
      expect(spot.lat, isA<double>());
      expect(spot.lng, isA<double>());
    });

    test('createdAt doğru parse edilir', () {
      final spot = SpotModel.fromJson(baseJson);
      expect(spot.createdAt.year, 2025);
      expect(spot.createdAt.month, 1);
      expect(spot.createdAt.day, 15);
    });
  });

  group('SpotModel.toJson', () {
    test('toJson → fromJson round-trip', () {
      final original = SpotModel.fromJson(baseJson);
      final json = original.toJson();
      final restored = SpotModel.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.lat, original.lat);
      expect(restored.privacyLevel, original.privacyLevel);
      expect(restored.verified, original.verified);
      expect(restored.muhtarId, original.muhtarId);
    });

    test('toJson doğru key isimleri kullanır', () {
      final spot = SpotModel.fromJson(baseJson);
      final json = spot.toJson();
      expect(json.containsKey('user_id'), isTrue);
      expect(json.containsKey('privacy_level'), isTrue);
      expect(json.containsKey('muhtar_id'), isTrue);
    });
  });

  group('SpotModel.copyWith', () {
    test('copyWith sadece belirtilen alanı değiştirir', () {
      final original = SpotModel.fromJson(baseJson);
      final updated = original.copyWith(name: 'Yeni Ad');
      expect(updated.name, 'Yeni Ad');
      expect(updated.id, original.id);
      expect(updated.lat, original.lat);
      expect(updated.privacyLevel, original.privacyLevel);
    });

    test('copyWith privacyLevel değiştirilebilir', () {
      final original = SpotModel.fromJson(baseJson);
      final updated = original.copyWith(privacyLevel: 'vip');
      expect(updated.privacyLevel, 'vip');
      expect(updated.name, original.name);
    });
  });
}
