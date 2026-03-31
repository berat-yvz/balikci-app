import 'dart:math' as math;

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu servisi — Supabase weather_cache tablosundan okur.
/// M-04 Hava Durumu & Cache — MVP_PLAN.md referans.
///
/// Mimari: Open-Meteo → Edge Function / spot-create hook → weather_cache → bu servis
class WeatherService {
  WeatherService._();

  static final _db = SupabaseService.client;

  static const double _cacheRadiusKm = 25;
  static const Duration _freshness = Duration(hours: 1);

  /// Kullanıcı konumuna en yakın (25km içinde) taze cache verisini döner.
  /// Bulunamazsa 25km içindeki en yakın (eski olabilir) cache döner.
  static Future<WeatherModel?> getWeatherForLocation({
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now().toUtc();
    final freshAfter = now.subtract(_freshness);

    final bbox = _bboxForRadiusKm(lat: lat, lng: lng, radiusKm: _cacheRadiusKm);

    try {
      final response = await _db
          .from('weather_cache')
          .select()
          .gte('lat', bbox.minLat)
          .lte('lat', bbox.maxLat)
          .gte('lng', bbox.minLng)
          .lte('lng', bbox.maxLng);

      final all = (response as List)
          .cast<Map<String, dynamic>>()
          .map(WeatherModel.fromJson)
          .toList();

      WeatherModel? bestFresh;
      double bestFreshDist = double.infinity;
      WeatherModel? bestAny;
      double bestAnyDist = double.infinity;

      for (final w in all) {
        final d = _haversineKm(lat, lng, w.lat, w.lng);
        if (d > _cacheRadiusKm) continue;

        if (d < bestAnyDist) {
          bestAnyDist = d;
          bestAny = w;
        }

        if (w.fetchedAt.toUtc().isAfter(freshAfter) && d < bestFreshDist) {
          bestFreshDist = d;
          bestFresh = w;
        }
      }

      return bestFresh ?? bestAny;
    } catch (_) {
      return null;
    }
  }

  /// Grid anahtarına (region_key) göre hava verisini döner.
  static Future<WeatherModel?> getWeatherByRegionKey(String regionKey) async {
    try {
      final response = await _db
          .from('weather_cache')
          .select()
          .eq('region_key', regionKey)
          .single();
      return WeatherModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Tüm cache kayıtlarını döner.
  static Future<List<WeatherModel>> getAllCaches() async {
    final response =
        await _db.from('weather_cache').select().order('fetched_at');
    return response.map<WeatherModel>(WeatherModel.fromJson).toList();
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = (MathHelpers.sin(dLat / 2) * MathHelpers.sin(dLat / 2)) +
        MathHelpers.cos(_degToRad(lat1)) *
            MathHelpers.cos(_degToRad(lat2)) *
            (MathHelpers.sin(dLng / 2) * MathHelpers.sin(dLng / 2));
    final c = 2 * MathHelpers.atan2(MathHelpers.sqrt(a), MathHelpers.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * 3.141592653589793 / 180.0;

  static _BBox _bboxForRadiusKm({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    // 1 deg lat ~ 111km. 1 deg lng ~ 111km * cos(lat)
    final dLat = radiusKm / 111.0;
    final cosLat = MathHelpers.cos(_degToRad(lat)).abs().clamp(0.2, 1.0);
    final dLng = radiusKm / (111.0 * cosLat);
    return _BBox(
      minLat: lat - dLat,
      maxLat: lat + dLat,
      minLng: lng - dLng,
      maxLng: lng + dLng,
    );
  }
}

class _BBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _BBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}

// dart:math kullanmadan küçük yardımcılar (min import + tree-shake)
class MathHelpers {
  static double sin(double x) => math.sin(x);
  static double cos(double x) => math.cos(x);
  static double sqrt(double x) => math.sqrt(x);
  static double atan2(double y, double x) => math.atan2(y, x);
}
