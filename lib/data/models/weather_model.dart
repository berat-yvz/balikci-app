/// Hava durumu modeli — ARCHITECTURE.md `weather_cache` tablosu referans.
/// MVP_PLAN.md M-04 balıkçı dili çevirisi bu model üzerinden çalışır.
class WeatherModel {
  // cleaned: ekran detayları için ek alanlar eklendi
  final String id;
  final double lat;
  final double lng;

  /// Open-Meteo'dan normalize edilerek yazılmış alanlar.
  final double? temperature; // °C
  final double? windspeed; // km/h
  final int? windDirection; // derece
  final double? waveHeight; // metre
  final double? seaSurfaceTemperature; // °C
  final double? precipitation; // mm
  final double? humidity; // %
  final double? visibilityKm; // km
  final double? cloudCover; // %
  final int? weatherCode;

  final String? fishingSummary; // Balıkçı dili özeti (Edge Function üretir)
  final DateTime fetchedAt;

  /// "lat_lng" formatında 0.25 derece grid anahtarı (unique).
  final String? regionKey;

  const WeatherModel({
    required this.id,
    required this.lat,
    required this.lng,
    required this.temperature,
    required this.windspeed,
    required this.windDirection,
    required this.waveHeight,
    required this.seaSurfaceTemperature,
    required this.precipitation,
    required this.humidity,
    required this.visibilityKm,
    required this.cloudCover,
    required this.weatherCode,
    required this.fishingSummary,
    required this.fetchedAt,
    required this.regionKey,
  });

  double get tempCelsius => (temperature ?? 0).toDouble();
  double get windKmh => (windspeed ?? 0).toDouble();

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    // data_json: OpenWeather API response (JSONB, units=metric → Celsius)
    final dataJson = json['data_json'] as Map<String, dynamic>?;
    final main    = dataJson?['main']   as Map<String, dynamic>?;
    final wind    = dataJson?['wind']   as Map<String, dynamic>?;
    final clouds  = dataJson?['clouds'] as Map<String, dynamic>?;
    final rain    = dataJson?['rain']   as Map<String, dynamic>?;
    final weatherList = dataJson?['weather'] as List?;
    final windSpeedMs = (wind?['speed'] as num?)?.toDouble();

    return WeatherModel(
      id: json['id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      temperature: (main?['temp'] as num?)?.toDouble(),          // already °C
      windspeed: windSpeedMs != null ? windSpeedMs * 3.6 : null, // m/s → km/h
      windDirection: (wind?['deg'] as num?)?.toInt(),
      waveHeight: null, // OpenWeather basic API'de yok
      seaSurfaceTemperature: null,
      precipitation: (rain?['1h'] as num?)?.toDouble(),
      humidity: (main?['humidity'] as num?)?.toDouble(),
      visibilityKm: dataJson?['visibility'] != null
          ? (dataJson!['visibility'] as num).toDouble() / 1000
          : null,
      cloudCover: (clouds?['all'] as num?)?.toDouble(),
      weatherCode: (weatherList != null && weatherList.isNotEmpty)
          ? (weatherList[0] as Map<String, dynamic>)['id'] as int? ?? 800
          : 800,
      fishingSummary: json['fishing_summary'] as String?,
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      regionKey: json['region_key'] as String?,
    );
  }
}
