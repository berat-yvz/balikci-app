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
    humidity: (json['humidity'] as num?)?.toDouble(),
    visibilityKm:
        (json['visibility_km'] as num?)?.toDouble() ??
        ((json['visibility'] as num?)?.toDouble() != null
            ? (json['visibility'] as num).toDouble() / 1000
            : null),
    cloudCover:
        (json['cloud_cover'] as num?)?.toDouble() ??
        (json['cloudiness'] as num?)?.toDouble(),
    weatherCode: json['weather_code'] as int?,
    fishingSummary: json['fishing_summary'] as String?,
    fetchedAt: DateTime.parse(json['fetched_at'] as String),
    regionKey: json['region_key'] as String?,
  );
}
