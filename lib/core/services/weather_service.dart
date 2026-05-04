import 'dart:math' as math;

import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/istanbul_ilce_resolver.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu — yalnızca Supabase `weather_cache` (Open-Meteo, Edge `weather-cache`).
/// İstemci Open-Meteo çağırmaz; güncelleme sunucu cron + Edge Function ile saatliktir.
class WeatherService {
  WeatherService._();

  static final _db = SupabaseService.client;

  static const double _fallbackLat = 41.0082;
  static const double _fallbackLng = 28.9784;

  /// Bölge anahtarına göre cache satırı + saatlik liste.
  static Future<RegionalWeatherData?> fetchRegionalWeatherFromSupabase(
    String regionKey,
  ) async {
    try {
      final response = await _db
          .from('weather_cache')
          .select()
          .eq('region_key', regionKey)
          .maybeSingle();
      if (response == null) return null;
      final row = Map<String, dynamic>.from(response);
      final current = WeatherModel.fromJson(row);
      final hourly = hourlyFromOpenMeteoV1Bundle(current.dataJson);
      if (hourly.isEmpty && current.dataJson?['source'] != 'open_meteo_v1') {
        return RegionalWeatherData(hourly: const [], current: current);
      }
      return RegionalWeatherData(hourly: hourly, current: current);
    } catch (_) {
      return null;
    }
  }

  /// [lat],[lng]’e en yakın tanımlı kıyı bölgesi.
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

  /// Mera / harita: en yakın bölgenin cache kaydı.
  static Future<WeatherModel?> getWeatherForLocation({
    required double lat,
    required double lng,
  }) async {
    final regionKey = nearestWeatherRegionKey(lat, lng);
    return getWeatherByRegionKey(regionKey);
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

  /// Mera detay sheet: İstanbul’da ilçe bazlı `weather_cache`, aksi halde 12 kıyı bölgesi.
  static Future<MeraWeatherSnapshot?> fetchMeraSheetWeather({
    required double lat,
    required double lng,
  }) async {
    final ilce = IstanbulIlceResolver.nearestIlce(lat, lng);
    if (ilce != null) {
      var snap = await fetchRegionalWeatherFromSupabase(ilce.regionKey);
      String locationLabel = ilce.displayName;
      var locationSubtitle = 'İstanbul · ilçe saatlik tahmin';
      if (snap == null) {
        snap = await fetchRegionalWeatherFromSupabase('istanbul');
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
    final snap = await fetchRegionalWeatherFromSupabase(regionKey);
    if (snap == null) return null;
    final hour = currentHourFromHourly(snap.hourly);
    return MeraWeatherSnapshot(
      weather: snap.current,
      currentHour: hour,
      locationLabel: _coastalRegionDisplayName(regionKey),
      locationSubtitle: 'Kıyı bölgesi · saatlik tahmin',
      dataRegionKey: regionKey,
    );
  }

  static String _coastalRegionDisplayName(String regionKey) {
    const names = <String, String>{
      'istanbul': 'İstanbul',
      'izmir': 'İzmir',
      'antalya': 'Antalya',
      'trabzon': 'Trabzon',
      'canakkale': 'Çanakkale',
      'bodrum': 'Bodrum',
      'fethiye': 'Fethiye',
      'sinop': 'Sinop',
      'samsun': 'Samsun',
      'mersin': 'Mersin',
      'mugla': 'Muğla',
      'balikesir': 'Balıkesir',
    };
    return names[regionKey] ?? regionKey;
  }

  static Future<WeatherModel?> getWeatherByRegionKey(String regionKey) async {
    try {
      final response = await _db
          .from('weather_cache')
          .select()
          .eq('region_key', regionKey)
          .maybeSingle();
      if (response == null) return null;
      return WeatherModel.fromJson(Map<String, dynamic>.from(response));
    } catch (_) {
      return null;
    }
  }

  /// Geriye dönük uyumluluk — artık doğrudan API yok; Supabase’ten okur.
  static Future<List<HourlyWeatherModel>> fetchHourlyForecast({
    double lat = _fallbackLat,
    double lng = _fallbackLng,
  }) async {
    final key = nearestWeatherRegionKey(lat, lng);
    final snap = await fetchRegionalWeatherFromSupabase(key);
    return snap?.hourly ?? const [];
  }

  static Future<List<HourlyWeatherModel>> fetchIstanbulHourlyForecast() =>
      fetchHourlyForecast(lat: _fallbackLat, lng: _fallbackLng);

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
      } catch (_) {
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
class RegionalWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel current;

  const RegionalWeatherData({
    required this.hourly,
    required this.current,
  });

  double get lat => current.lat;
  double get lng => current.lng;
}
