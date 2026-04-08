/// Saatlik hava tahmin verisi — Open-Meteo API'den gelen tek saat dilimi.
class HourlyWeatherModel {
  final DateTime time;
  final double temperature; // °C
  final double windspeed; // km/h
  final double precipitation; // mm
  final int weatherCode; // Open-Meteo WMO kodu

  const HourlyWeatherModel({
    required this.time,
    required this.temperature,
    required this.windspeed,
    required this.precipitation,
    required this.weatherCode,
  });

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

  factory HourlyWeatherModel.fromOpenMeteo({
    required String timeStr,
    required double temperature,
    required double windspeed,
    required double precipitation,
    required int weatherCode,
  }) {
    return HourlyWeatherModel(
      time: DateTime.parse(timeStr),
      temperature: temperature,
      windspeed: windspeed,
      precipitation: precipitation,
      weatherCode: weatherCode,
    );
  }
}
