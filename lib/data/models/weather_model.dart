/// Hava durumu modeli — ARCHITECTURE.md `weather_cache` tablosu referans.
/// MVP_PLAN.md M-04 balıkçı dili çevirisi bu model üzerinden çalışır.
class WeatherModel {
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
    required this.weatherCode,
    required this.fishingSummary,
    required this.fetchedAt,
    required this.regionKey,
  });

  double get tempCelsius => (temperature ?? 0).toDouble();
  double get windKmh => (windspeed ?? 0).toDouble();

  factory WeatherModel.fromJson(Map<String, dynamic> json) => WeatherModel(
    id: json['id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    temperature: (json['temperature'] as num?)?.toDouble(),
    windspeed: (json['windspeed'] as num?)?.toDouble(),
    windDirection: json['wind_direction'] as int?,
    waveHeight: (json['wave_height'] as num?)?.toDouble(),
    seaSurfaceTemperature: (json['sea_surface_temperature'] as num?)
        ?.toDouble(),
    precipitation: (json['precipitation'] as num?)?.toDouble(),
    weatherCode: json['weather_code'] as int?,
    fishingSummary: json['fishing_summary'] as String?,
    fetchedAt: DateTime.parse(json['fetched_at'] as String),
    regionKey: json['region_key'] as String?,
  );
}
