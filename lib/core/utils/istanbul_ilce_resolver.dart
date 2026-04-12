import 'dart:math' as math;

import 'package:balikci_app/core/constants/istanbul_ilce_weather.dart';

/// Mera koordinatından İstanbul ilçe `weather_cache` anahtarı üretir.
class IstanbulIlceResolver {
  IstanbulIlceResolver._();

  static bool isInIstanbulMetro(double lat, double lng) {
    return lat >= 40.72 &&
        lat <= 41.45 &&
        lng >= 27.85 &&
        lng <= 30.12;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Metro içindeyse en yakın ilçe; değilse `null`.
  static IstanbulIlceWeatherPoint? nearestIlce(double lat, double lng) {
    if (!isInIstanbulMetro(lat, lng)) return null;
    IstanbulIlceWeatherPoint? best;
    var bestD = double.infinity;
    for (final p in istanbulIlceWeatherPoints) {
      final d = _haversineKm(lat, lng, p.lat, p.lng);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }
}
