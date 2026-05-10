import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/istanbul_ilce_resolver.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu — sunucu `weather_cache` + yerel Drift.
///
/// - Open-Meteo **yalnızca** Edge `weather-cache` (pg_cron, saat başı) ile çağrılır.
/// - İstemci `weather_cache` okumasını **yalnızca** planlı senkronla yapar (İstanbul XX:02);
///   bunun dışında yalnızca Drift okur (harita mera kartı dahil).
class WeatherService {
  WeatherService._();

  static final _db = SupabaseService.client;
  static final _driftDb = AppDatabase.instance;

  /// `istanbul` kıyı anahtarı bazen worker'da diğerlerinden eski kalabiliyor; taze ilçe
  /// satırı Drift'te varsa aynı paketi bölge adıyla sunarız (ekstra ağ isteği yok).
  static const Duration _coastalStaleFallbackAfter = Duration(minutes: 75);
  static const String _istanbulFreshFallbackRowKey = 'istanbul_ilce_fatih';

  static Future<RegionalWeatherData> _applyCoastalFreshRowFallbackFromDrift(
    String regionKey,
    RegionalWeatherData pack,
  ) async {
    if (pack.isFromCache || regionKey != 'istanbul') return pack;
    final age =
        DateTime.now().toUtc().difference(pack.current.fetchedAt.toUtc());
    if (age <= _coastalStaleFallbackAfter) return pack;

    final fbPack =
        await loadRegionalWeatherFromDrift(_istanbulFreshFallbackRowKey);
    if (fbPack == null) return pack;
    final fb = fbPack.current;
    if (!fb.fetchedAt.isAfter(pack.current.fetchedAt)) return pack;

    final meta = weatherRegions[regionKey];
    if (meta == null) return pack;
    final hourly = hourlyFromOpenMeteoV1Bundle(fb.dataJson);
    final current = fb.withDisplayRegion(
      regionKey: regionKey,
      lat: meta['lat']!,
      lng: meta['lng']!,
    );
    return RegionalWeatherData(hourly: hourly, current: current);
  }

  /// Yalnızca Drift — ağ yok. Harita mera sheet ve anlık gösterim için.
  static Future<RegionalWeatherData?> loadRegionalWeatherFromDrift(
    String regionKey,
  ) async {
    try {
      final cached = await (_driftDb.select(_driftDb.localWeather)
            ..where((t) => t.regionKey.equals(regionKey)))
          .getSingleOrNull();
      if (cached == null) return null;

      final decodedDataJson = (() {
        try {
          return cached.dataJson != null
              ? jsonDecode(cached.dataJson!) as Map<String, dynamic>
              : null;
        } catch (e) {
          debugPrint('[WeatherService] dataJson decode hatası: $e');
          return null;
        }
      })();

      WeatherModel current;
      if (decodedDataJson != null) {
        try {
          current = WeatherModel.fromJson({
            'id': '',
            'lat': weatherRegions[cached.regionKey]?['lat'] ?? 0.0,
            'lng': weatherRegions[cached.regionKey]?['lng'] ?? 0.0,
            'fetched_at': cached.cachedAt.toUtc().toIso8601String(),
            'region_key': cached.regionKey,
            'data_json': decodedDataJson,
            'fishing_summary': null,
          });
        } catch (e, st) {
          debugPrint('[WeatherService] Drift cache fromJson hatası: $e\n$st');
          current = _buildModelFromCachedFields(cached, decodedDataJson);
        }
      } else {
        current = _buildModelFromCachedFields(cached, null);
      }

      final cachedHourly = hourlyFromOpenMeteoV1Bundle(decodedDataJson);
      // Drift = planlı senkron sonrası normal depo; "çevrimdışı" yalnızca eksik veride.
      return RegionalWeatherData(
        hourly: cachedHourly,
        current: current,
        isFromCache: cachedHourly.isEmpty,
      );
    } catch (e, st) {
      debugPrint('[WeatherService] Drift okuma hatası ($regionKey): $e\n$st');
      return null;
    }
  }

  /// Supabase `weather_cache` tek okuma + Drift yaz; istenirse ağ hatasında Drift'e düş.
  /// [fallbackToDrift] false iken (planlı senkron) hata durumunda null döner.
  static Future<RegionalWeatherData?> syncRegionalWeatherFromSupabase(
    String regionKey, {
    bool fallbackToDrift = true,
  }) async {
    try {
      final response = await _db
          .from('weather_cache')
          .select()
          .eq('region_key', regionKey)
          .maybeSingle();
      if (response == null) return null;
      final row = Map<String, dynamic>.from(response);
      if (kDebugMode) {
        debugPrint('[WeatherService] Supabase yanıtı ($regionKey): '
            'region_key=${row['region_key']}, '
            'fetched_at=${row['fetched_at']}, '
            'source=${(row['data_json'] as Map<String, dynamic>?)?['source']}');
      }
      final current = WeatherModel.fromJson(row);
      final hourly = hourlyFromOpenMeteoV1Bundle(current.dataJson);
      final pack = await _applyCoastalFreshRowFallbackFromDrift(
        regionKey,
        hourly.isEmpty && current.dataJson?['source'] != 'open_meteo_v1'
            ? RegionalWeatherData(hourly: const [], current: current)
            : RegionalWeatherData(hourly: hourly, current: current),
      );
      try {
        final c = pack.current;
        await _driftDb.into(_driftDb.localWeather).insertOnConflictUpdate(
              LocalWeatherCompanion.insert(
                regionKey: regionKey,
                tempC: Value(c.temperature ?? 0.0),
                windSpeedKmh: Value(c.windspeed ?? 0.0),
                waveHeightM: Value(c.waveHeight ?? 0.0),
                humidity: Value(c.humidity ?? 0.0),
                cachedAt: c.fetchedAt,
                windDirection: Value(c.windDirection),
                cloudCover: Value(c.cloudCover),
                visibilityKm: Value(c.visibilityKm),
                precipitation: Value(c.precipitation),
                seaSurfaceTemperature: Value(c.seaSurfaceTemperature),
                pressureHpa: Value(c.pressureHpa),
                dataJson: Value(
                  c.dataJson != null ? jsonEncode(c.dataJson) : null,
                ),
              ),
            );
      } catch (e, st) {
        debugPrint('[WeatherService] Drift write hatası: $e\n$st');
      }
      return RegionalWeatherData(
        hourly: pack.hourly,
        current: pack.current,
        isFromCache: false,
      );
    } catch (e, st) {
      debugPrint('[WeatherService] Supabase fetch hatası ($regionKey): $e\n$st');
      if (!fallbackToDrift) return null;
      return loadRegionalWeatherFromDrift(regionKey);
    }
  }

  /// Drift alanlarından manuel WeatherModel — dataJson yoksa ya da fromJson başarısız olursa.
  static WeatherModel _buildModelFromCachedFields(
    dynamic cached,
    Map<String, dynamic>? dataJson,
  ) {
    final regionKey = cached.regionKey as String;
    return WeatherModel(
      id: '',
      lat: weatherRegions[regionKey]?['lat'] ?? 0.0,
      lng: weatherRegions[regionKey]?['lng'] ?? 0.0,
      dataJson: dataJson,
      temperature: cached.tempC as double?,
      windspeed: cached.windSpeedKmh as double?,
      windDirection: cached.windDirection as int?,
      waveHeight: cached.waveHeightM as double?,
      seaSurfaceTemperature: cached.seaSurfaceTemperature as double?,
      precipitation: cached.precipitation as double?,
      humidity: cached.humidity as double?,
      visibilityKm: cached.visibilityKm as double?,
      cloudCover: cached.cloudCover as double?,
      pressureHpa: cached.pressureHpa as double?,
      weatherCode: null,
      fishingSummary: null,
      fetchedAt: cached.cachedAt.toUtc(),
      regionKey: regionKey,
    );
  }

  /// [lat],[lng]'e en yakın tanımlı kıyı bölgesi.
  static String nearestWeatherRegionKey(double lat, double lng) {
    var best = double.infinity;
    var key = 'istanbul';
    weatherRegions.forEach((k, v) {
      final d = _haversineKm(lat, lng, v['lat']!, v['lng']!);
      if (d < best) {
        best = d;
        key = k;
      }
    });
    return key;
  }

  /// Şu anki saat dilimine denk gelen saatlik satır (tahmin başlangıcı).
  static HourlyWeatherModel? currentHourFromHourly(
    List<HourlyWeatherModel> hourly,
  ) {
    if (hourly.isEmpty) return null;
    final now = DateTime.now();
    final slot = DateTime(now.year, now.month, now.day, now.hour);
    final filtered = hourly.where((h) => !h.time.isBefore(slot)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (filtered.isNotEmpty) return filtered.first;
    return hourly.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
  }

  /// Mera detay sheet: yalnızca Drift önbelleği (ağ yok).
  static Future<MeraWeatherSnapshot?> fetchMeraSheetWeather({
    required double lat,
    required double lng,
  }) async {
    final ilce = IstanbulIlceResolver.nearestIlce(lat, lng);
    if (ilce != null) {
      var snap = await loadRegionalWeatherFromDrift(ilce.regionKey);
      String locationLabel = ilce.displayName;
      var locationSubtitle = 'İstanbul · ilçe saatlik tahmin';
      if (snap == null) {
        snap = await loadRegionalWeatherFromDrift('istanbul');
        locationLabel = 'İstanbul';
        locationSubtitle = 'Genel özet (ilçe önbelleği yok)';
      }
      if (snap == null) return null;
      final hour = currentHourFromHourly(snap.hourly);
      return MeraWeatherSnapshot(
        weather: snap.current,
        currentHour: hour,
        locationLabel: locationLabel,
        locationSubtitle: locationSubtitle,
        dataRegionKey: snap.current.regionKey ?? 'istanbul',
      );
    }

    final regionKey = nearestWeatherRegionKey(lat, lng);
    final snap = await loadRegionalWeatherFromDrift(regionKey);
    if (snap == null) return null;
    final hour = currentHourFromHourly(snap.hourly);
    return MeraWeatherSnapshot(
      weather: snap.current,
      currentHour: hour,
      locationLabel: weatherRegionDisplayNames[regionKey] ?? regionKey,
      locationSubtitle: 'Kıyı bölgesi · saatlik tahmin',
      dataRegionKey: regionKey,
    );
  }

  static List<HourlyWeatherModel> hourlyFromOpenMeteoV1Bundle(
    Map<String, dynamic>? dataJson,
  ) {
    if (dataJson == null || dataJson['source'] != 'open_meteo_v1') {
      return const [];
    }
    final raw = dataJson['hourly'];
    if (raw is! List) return const [];
    final out = <HourlyWeatherModel>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      try {
        out.add(
          HourlyWeatherModel.fromOpenMeteo(
            timeStr: m['time'] as String,
            temperature: (m['temperature'] as num).toDouble(),
            windspeed: (m['windspeed'] as num).toDouble(),
            precipitation: (m['precipitation'] as num).toDouble(),
            weatherCode: (m['weather_code'] as num).toInt(),
            cloudCover: (m['cloud_cover'] as num?)?.toDouble(),
            waveHeight: (m['wave_height'] as num?)?.toDouble(),
            seaSurfaceTemperature:
                (m['sea_surface_temperature'] as num?)?.toDouble(),
            currentVelocity: (m['ocean_current_velocity'] as num?)?.toDouble(),
            currentDirection: (m['ocean_current_direction'] as num?)?.toDouble(),
            visibilityMeters: (m['visibility_m'] as num?)?.toDouble(),
            windDirection: (m['wind_direction'] as num?)?.toInt(),
          ),
        );
      } catch (e) {
        debugPrint('[WeatherService] hourly satır parse hatası: $e');
        continue;
      }
    }
    return out;
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
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}

/// Harita mera sheet — saatlik satırdan sıcaklık / rüzgar / dalga / durum.
class MeraWeatherSnapshot {
  final WeatherModel weather;
  final HourlyWeatherModel? currentHour;

  /// İlçe veya kıyı bölgesi adı (kart başlığı).
  final String locationLabel;
  final String locationSubtitle;
  final String dataRegionKey;

  const MeraWeatherSnapshot({
    required this.weather,
    required this.currentHour,
    required this.locationLabel,
    required this.locationSubtitle,
    required this.dataRegionKey,
  });
}

/// Supabase `weather_cache` satırından üretilen anlık + saatlik paket.
/// [isFromCache] — true ise Supabase başarısız oldu, Drift local cache'ten geldi.
class RegionalWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel current;

  /// Supabase yerine Drift local cache'ten yüklendiğini belirtir.
  final bool isFromCache;

  const RegionalWeatherData({
    required this.hourly,
    required this.current,
    this.isFromCache = false,
  });

  double get lat => current.lat;
  double get lng => current.lng;
}
