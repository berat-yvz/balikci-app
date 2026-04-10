import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceInMeters', () {
    test('aynı koordinat → sıfır mesafe', () {
      final dist = GeoUtils.distanceInMeters(
        lat1: 41.0082,
        lng1: 28.9784,
        lat2: 41.0082,
        lng2: 28.9784,
      );
      expect(dist, closeTo(0.0, 0.001));
    });

    test('İstanbul → Kadıköy yaklaşık 7km', () {
      // Taksim: 41.0370, 28.9850  |  Kadıköy: 40.9900, 29.0230
      final dist = GeoUtils.distanceInMeters(
        lat1: 41.0370,
        lng1: 28.9850,
        lat2: 40.9900,
        lng2: 29.0230,
      );
      expect(dist, inInclusiveRange(6000, 8000));
    });

    test('Kuzey kutbu → güney kutbu yaklaşık 20003km', () {
      final dist = GeoUtils.distanceInMeters(
        lat1: 90.0,
        lng1: 0.0,
        lat2: -90.0,
        lng2: 0.0,
      );
      expect(dist, closeTo(20003930, 50000));
    });

    test('mesafe simetrik — A→B == B→A', () {
      final ab = GeoUtils.distanceInMeters(
        lat1: 41.0, lng1: 28.0, lat2: 40.0, lng2: 29.0,
      );
      final ba = GeoUtils.distanceInMeters(
        lat1: 40.0, lng1: 29.0, lat2: 41.0, lng2: 28.0,
      );
      expect(ab, closeTo(ba, 0.001));
    });
  });

  group('GeoUtils.isWithinSpot', () {
    const spotLat = 41.0082;
    const spotLng = 28.9784;

    test('aynı konum → 500m içinde', () {
      expect(
        GeoUtils.isWithinSpot(
          userLat: spotLat, userLng: spotLng,
          spotLat: spotLat, spotLng: spotLng,
        ),
        isTrue,
      );
    });

    test('100m uzakta → 500m içinde', () {
      // ~100m kuzey: +0.0009 derece enlem
      expect(
        GeoUtils.isWithinSpot(
          userLat: spotLat + 0.0009,
          userLng: spotLng,
          spotLat: spotLat,
          spotLng: spotLng,
        ),
        isTrue,
      );
    });

    test('1000m uzakta → 500m dışında (varsayılan)', () {
      // ~1km kuzey: +0.009 derece enlem
      expect(
        GeoUtils.isWithinSpot(
          userLat: spotLat + 0.009,
          userLng: spotLng,
          spotLat: spotLat,
          spotLng: spotLng,
        ),
        isFalse,
      );
    });

    test('özel yarıçap 1000m ile 1000m mesafe → içinde', () {
      expect(
        GeoUtils.isWithinSpot(
          userLat: spotLat + 0.009,
          userLng: spotLng,
          spotLat: spotLat,
          spotLng: spotLng,
          radiusMeters: 1100,
        ),
        isTrue,
      );
    });

    test('501m uzakta → varsayılan 500m dışında', () {
      // ~501m → yaklaşık 0.00451 derece
      final dist = GeoUtils.distanceInMeters(
        lat1: spotLat + 0.00451, lng1: spotLng,
        lat2: spotLat, lng2: spotLng,
      );
      // 500m'yi geçtiğini doğrula
      expect(dist, greaterThan(500));
      expect(
        GeoUtils.isWithinSpot(
          userLat: spotLat + 0.00451,
          userLng: spotLng,
          spotLat: spotLat,
          spotLng: spotLng,
        ),
        isFalse,
      );
    });
  });
}
