import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/shop_model.dart';

void main() {
  final baseJson = {
    'id': 'shop-1',
    'name': 'Kadıköy Olta Malzemeleri',
    'lat': 40.9900,
    'lng': 29.0238,
    'type': 'olta_malzemesi',
    'phone': '+90 216 345 9876',
    'hours': '09:00-21:00',
    'added_by': 'user-1',
    'verified': true,
  };

  group('ShopModel.fromJson', () {
    test('tam veriyle parse edilir', () {
      final shop = ShopModel.fromJson(baseJson);
      expect(shop.id, 'shop-1');
      expect(shop.name, 'Kadıköy Olta Malzemeleri');
      expect(shop.lat, closeTo(40.9900, 0.0001));
      expect(shop.lng, closeTo(29.0238, 0.0001));
      expect(shop.type, 'olta_malzemesi');
      expect(shop.phone, '+90 216 345 9876');
      expect(shop.hours, '09:00-21:00');
      expect(shop.addedBy, 'user-1');
      expect(shop.verified, isTrue);
    });

    test('eksik opsiyonel alanlar null döner', () {
      final minimal = {
        'id': 'shop-2',
        'name': 'Test Dükkan',
        'lat': 41.0,
        'lng': 29.0,
        'type': 'balikci_dukkani',
      };
      final shop = ShopModel.fromJson(minimal);
      expect(shop.phone, isNull);
      expect(shop.hours, isNull);
      expect(shop.addedBy, isNull);
      expect(shop.verified, isFalse);
    });

    test('lat/lng integer olarak gelse de double\'a çevrilir', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['lat'] = 41;
      json['lng'] = 29;
      final shop = ShopModel.fromJson(json);
      expect(shop.lat, isA<double>());
      expect(shop.lng, isA<double>());
    });

    test('verified null → false varsayılan', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['verified'] = null;
      final shop = ShopModel.fromJson(json);
      expect(shop.verified, isFalse);
    });
  });

  group('ShopModel türleri', () {
    for (final type in [
      'balikci_dukkani',
      'olta_malzemesi',
      'tekne_kiralama',
      'balikci_barina',
      'nalbur',
    ]) {
      test('$type tipi parse edilir', () {
        final json = Map<String, dynamic>.from(baseJson);
        json['type'] = type;
        final shop = ShopModel.fromJson(json);
        expect(shop.type, type);
      });
    }
  });
}
