/// Saatlik hava tahmin verisi — Open-Meteo forecast + marine API.
class HourlyWeatherModel {
  final DateTime time;
  final double temperature; // °C
  final double windspeed; // km/h
  final double precipitation; // mm
  final int weatherCode; // Open-Meteo WMO kodu
  final double? waveHeight; // metre (marine-api.open-meteo.com)

  const HourlyWeatherModel({
    required this.time,
    required this.temperature,
    required this.windspeed,
    required this.precipitation,
    required this.weatherCode,
    this.waveHeight,
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
    double? waveHeight,
  }) {
    return HourlyWeatherModel(
      time: DateTime.parse(timeStr),
      temperature: temperature,
      windspeed: windspeed,
      precipitation: precipitation,
      weatherCode: weatherCode,
      waveHeight: waveHeight,
    );
  }
}
