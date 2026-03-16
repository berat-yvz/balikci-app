/// Hava durumu modeli — ARCHITECTURE.md `weather_cache` tablosu referans.
/// MVP_PLAN.md M-04 balıkçı dili çevirisi bu model üzerinden çalışır.
class WeatherModel {
  final String id;
  final String regionKey;
  final double lat;
  final double lng;
  final Map<String, dynamic> dataJson; // OpenWeatherMap raw response
  final String? fishingSummary; // Balıkçı dili özeti (Edge Function üretir)
  final DateTime fetchedAt;

  const WeatherModel({
    required this.id,
    required this.regionKey,
    required this.lat,
    required this.lng,
    required this.dataJson,
    this.fishingSummary,
    required this.fetchedAt,
  });

  /// Sıcaklık (°C)
  double get tempCelsius =>
      ((dataJson['main']?['temp'] as num?) ?? 0).toDouble() - 273.15;

  /// Rüzgar hızı (km/h)
  double get windKmh =>
      ((dataJson['wind']?['speed'] as num?) ?? 0).toDouble() * 3.6;

  /// Hava kodu (800 = açık, 500-504 = yağmur, vb.)
  int get weatherCode =>
      (dataJson['weather']?[0]?['id'] as int?) ?? 800;

  factory WeatherModel.fromJson(Map<String, dynamic> json) => WeatherModel(
        id: json['id'] as String,
        regionKey: json['region_key'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        dataJson: json['data_json'] as Map<String, dynamic>,
        fishingSummary: json['fishing_summary'] as String?,
        fetchedAt: DateTime.parse(json['fetched_at'] as String),
      );
}
