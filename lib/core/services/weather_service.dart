import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu servisi — Supabase weather_cache tablosundan okur.
/// M-04 Hava Durumu & Cache — MVP_PLAN.md referans.
///
/// Mimari: OpenWeatherMap → Edge Function (cron 4h) → weather_cache → bu servis
/// Uygulama hiçbir zaman OpenWeatherMap'e doğrudan istek atmaz.
class WeatherService {
  WeatherService._();

  static final _db = SupabaseService.client;

  /// Kullanıcı konumuna en yakın bölgenin hava verisini döner.
  static Future<WeatherModel?> getWeatherForLocation({
    required double lat,
    required double lng,
  }) async {
    final regionKey = _findNearestRegion(lat, lng);
    return getWeatherByRegion(regionKey);
  }

  /// Bölge anahtarına göre hava verisini döner.
  static Future<WeatherModel?> getWeatherByRegion(String regionKey) async {
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

  /// Tüm bölgelerin hava verilerini döner.
  static Future<List<WeatherModel>> getAllRegions() async {
    final response =
        await _db.from('weather_cache').select().order('region_key');
    return response.map<WeatherModel>(WeatherModel.fromJson).toList();
  }

  /// Haversine ile en yakın bölge anahtarını bulur.
  static String _findNearestRegion(double lat, double lng) {
    String nearest = 'istanbul';
    double minDist = double.infinity;

    for (final entry in weatherRegions.entries) {
      final rLat = entry.value['lat']!;
      final rLng = entry.value['lng']!;
      final dist = (lat - rLat) * (lat - rLat) + (lng - rLng) * (lng - rLng);
      if (dist < minDist) {
        minDist = dist;
        nearest = entry.key;
      }
    }
    return nearest;
  }
}
