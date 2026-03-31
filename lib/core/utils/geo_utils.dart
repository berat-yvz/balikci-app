import 'dart:math';

/// Mesafe hesaplama yardımcıları — Haversine formülü.
/// M-03 Check-in: kullanıcı mera ±500m içinde mi?
class GeoUtils {
  GeoUtils._();

  static const _earthRadiusMeters = 6371000.0;

  /// İki koordinat arasındaki mesafeyi metre cinsinden döner.
  static double distanceInMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Kullanıcı meranın içinde mi? (±500m)
  static bool isWithinSpot({
    required double userLat,
    required double userLng,
    required double spotLat,
    required double spotLng,
    double radiusMeters = 500,
  }) {
    return distanceInMeters(
          lat1: userLat,
          lng1: userLng,
          lat2: spotLat,
          lng2: spotLng,
        ) <=
        radiusMeters;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
