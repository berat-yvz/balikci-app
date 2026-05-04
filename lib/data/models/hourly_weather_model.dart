/// Saatlik hava tahmin verisi — Open-Meteo forecast + marine API.
class HourlyWeatherModel {
  final DateTime time;
  final double temperature;             // °C (hava)
  final double windspeed;              // km/h
  final double precipitation;          // mm
  final int weatherCode;               // Open-Meteo WMO kodu
  final double? cloudCover;            // % (0–100) — forecast API
  final double? waveHeight;            // m (marine-api)
  final double? seaSurfaceTemperature; // °C (marine-api)
  final double? currentVelocity;       // m/s (marine-api)
  final double? currentDirection;      // derece, 0=kuzey (marine-api)
  /// Open-Meteo forecast `visibility` — metre cinsinden.
  final double? visibilityMeters;
  final int? windDirection; // derece, 0=Kuzey (Open-Meteo winddirection_10m)

  const HourlyWeatherModel({
    required this.time,
    required this.temperature,
    required this.windspeed,
    required this.precipitation,
    required this.weatherCode,
    this.cloudCover,
    this.waveHeight,
    this.seaSurfaceTemperature,
    this.currentVelocity,
    this.currentDirection,
    this.visibilityMeters,
    this.windDirection,
  });

  /// Görüş mesafesi (km); cache/OW ile aynı birimde kullanım için.
  double? get visibilityKm =>
      visibilityMeters == null ? null : visibilityMeters! / 1000.0;

  /// Open-Meteo WMO kodundan emoji döner.
  String get weatherEmoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 69) return '🌧️';
    if (weatherCode <= 79) return '❄️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  /// Akıntı yönünü ok karakterine çevirir (8 ana yön).
  String? get currentDirectionArrow {
    final d = currentDirection;
    if (d == null) return null;
    const arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];
    final index = ((d + 22.5) / 45).floor() % 8;
    return arrows[index];
  }

  factory HourlyWeatherModel.fromOpenMeteo({
    required String timeStr,
    required double temperature,
    required double windspeed,
    required double precipitation,
    required int weatherCode,
    double? cloudCover,
    double? waveHeight,
    double? seaSurfaceTemperature,
    double? currentVelocity,
    double? currentDirection,
    double? visibilityMeters,
    int? windDirection,
  }) {
    return HourlyWeatherModel(
      time: DateTime.parse(timeStr),
      temperature: temperature,
      windspeed: windspeed,
      precipitation: precipitation,
      weatherCode: weatherCode,
      cloudCover: cloudCover,
      waveHeight: waveHeight,
      seaSurfaceTemperature: seaSurfaceTemperature,
      currentVelocity: currentVelocity,
      currentDirection: currentDirection,
      visibilityMeters: visibilityMeters,
      windDirection: windDirection,
    );
  }
}
