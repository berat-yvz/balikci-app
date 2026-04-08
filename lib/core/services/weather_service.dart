import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:drift/drift.dart' as drift;

/// Hava durumu servisi — Supabase weather_cache tablosundan okur.
/// M-04 Hava Durumu & Cache — MVP_PLAN.md referans.
///
/// Mimari: Open-Meteo → Edge Function / spot-create hook → weather_cache → bu servis
class WeatherService {
  // cleaned: Drift cache + Supabase fallback akışı 30dk tazelikle güncellendi
  WeatherService._();

  static final _db = SupabaseService.client;
  static final _localDb = AppDatabase.instance;

  static const double _cacheRadiusKm = 25;
  static const Duration _freshness = Duration(minutes: 30);

  /// Kullanıcı konumuna en yakın (25km içinde) taze cache verisini döner.
  /// Bulunamazsa 25km içindeki en yakın (eski olabilir) cache döner.
  static Future<WeatherModel?> getWeatherForLocation({
    required double lat,
    required double lng,
  }) async {
    final regionKey = _regionKeyForLatLng(lat, lng);
    final local = await (_localDb.select(
      _localDb.localWeather,
    )..where((t) => t.regionKey.equals(regionKey))).getSingleOrNull();
    if (local != null &&
        DateTime.now().difference(local.cachedAt) <= _freshness) {
      return WeatherModel(
        id: 'local-$regionKey',
        lat: lat,
        lng: lng,
        temperature: local.tempC,
        windspeed: local.windSpeedKmh,
        windDirection: null,
        waveHeight: local.waveHeightM,
        seaSurfaceTemperature: null,
        precipitation: null,
        humidity: local.humidity,
        visibilityKm: null,
        cloudCover: null,
        weatherCode: null,
        fishingSummary: null,
        fetchedAt: local.cachedAt,
        regionKey: local.regionKey,
      );
    }

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

      final selected = bestFresh ?? bestAny;
      if (selected != null) {
        final key = selected.regionKey ?? regionKey;
        await _localDb
            .into(_localDb.localWeather)
            .insertOnConflictUpdate(
              LocalWeatherCompanion.insert(
                regionKey: key,
                tempC: selected.temperature == null
                    ? const drift.Value.absent()
                    : drift.Value(selected.temperature!),
                windSpeedKmh: selected.windspeed == null
                    ? const drift.Value.absent()
                    : drift.Value(selected.windspeed!),
                waveHeightM: selected.waveHeight == null
                    ? const drift.Value.absent()
                    : drift.Value(selected.waveHeight!),
                humidity: selected.humidity == null
                    ? const drift.Value.absent()
                    : drift.Value(selected.humidity!),
                cachedAt: DateTime.now(),
              ),
            );
      }
      return selected;
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

  static const double _istanbulLat = 41.0082;
  static const double _istanbulLng = 28.9784;

  /// İstanbul için Open-Meteo forecast + marine API'den 24 saatlik tahmin çeker.
  /// Dalga yükseklikleri marine-api.open-meteo.com'dan eklenir.
  /// Hata durumunda boş liste döner.
  static Future<List<HourlyWeatherModel>> fetchIstanbulHourlyForecast() async {
    try {
      // ── 1. Forecast (sıcaklık, rüzgar, yağış, kod) ──────────────────────
      final forecastUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$_istanbulLat'
        '&longitude=$_istanbulLng'
        '&hourly=temperature_2m,windspeed_10m,precipitation,weathercode'
        '&timezone=Europe%2FIstanbul'
        '&forecast_days=1',
      );

      // ── 2. Marine (dalga yüksekliği) ─────────────────────────────────────
      final marineUri = Uri.parse(
        'https://marine-api.open-meteo.com/v1/marine'
        '?latitude=$_istanbulLat'
        '&longitude=$_istanbulLng'
        '&hourly=wave_height'
        '&timezone=Europe%2FIstanbul'
        '&forecast_days=1',
      );

      final client = HttpClient();

      Future<String> fetch(Uri uri) async {
        final req = await client.getUrl(uri);
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        return body;
      }

      final forecastBody = await fetch(forecastUri);

      // Marine API opsiyonel — hata olsa da devam edilir.
      List<double?>? waveHeights;
      try {
        final marineBody = await fetch(marineUri);
        final marineData = jsonDecode(marineBody) as Map<String, dynamic>;
        final marineHourly = marineData['hourly'] as Map<String, dynamic>;
        waveHeights = (marineHourly['wave_height'] as List)
            .map((v) => v == null ? null : (v as num).toDouble())
            .toList();
      } catch (_) {
        // Marine verisi alınamazsa dalga gösterilmez; uygulama çalışmaya devam eder.
      }

      client.close();

      final data = jsonDecode(forecastBody) as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List;
      final temps = hourly['temperature_2m'] as List;
      final winds = hourly['windspeed_10m'] as List;
      final precips = hourly['precipitation'] as List;
      final codes = hourly['weathercode'] as List;

      final result = <HourlyWeatherModel>[];
      for (int i = 0; i < times.length; i++) {
        result.add(
          HourlyWeatherModel.fromOpenMeteo(
            timeStr: times[i] as String,
            temperature: (temps[i] as num).toDouble(),
            windspeed: (winds[i] as num).toDouble(),
            precipitation: (precips[i] as num).toDouble(),
            weatherCode: (codes[i] as num).toInt(),
            waveHeight: (waveHeights != null && i < waveHeights.length)
                ? waveHeights[i]
                : null,
          ),
        );
      }
      return result;
    } catch (_) {
      return [];
    }
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
    final a =
        (MathHelpers.sin(dLat / 2) * MathHelpers.sin(dLat / 2)) +
        MathHelpers.cos(_degToRad(lat1)) *
            MathHelpers.cos(_degToRad(lat2)) *
            (MathHelpers.sin(dLng / 2) * MathHelpers.sin(dLng / 2));
    final c =
        2 * MathHelpers.atan2(MathHelpers.sqrt(a), MathHelpers.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * 3.141592653589793 / 180.0;

  static String _regionKeyForLatLng(double lat, double lng) {
    final latBucket = (lat * 4).round() / 4;
    final lngBucket = (lng * 4).round() / 4;
    return '${latBucket.toStringAsFixed(2)}_${lngBucket.toStringAsFixed(2)}';
  }

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
