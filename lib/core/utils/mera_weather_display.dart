import 'package:balikci_app/data/models/hourly_weather_model.dart';

/// Mera detay kartı — yağış / açık özeti (Open-Meteo WMO kodu + mm).
class MeraWeatherDisplay {
  MeraWeatherDisplay._();

  /// Kullanıcıya kısa durum metni.
  static String skyCondition(HourlyWeatherModel hour) {
    return skyConditionFromWmo(
      weatherCode: hour.weatherCode,
      precipitationMm: hour.precipitation,
    );
  }

  /// Saatlik satır yoksa `WeatherModel` alanlarından.
  static String skyConditionFromWmo({
    required int weatherCode,
    required double precipitationMm,
  }) {
    final rainyCode = (weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82) ||
        (weatherCode >= 95 && weatherCode <= 99);
    if (precipitationMm >= 0.1 || rainyCode) {
      return 'Yağışlı';
    }
    if (weatherCode == 0 || weatherCode == 1) {
      return 'Açık';
    }
    if (weatherCode >= 2 && weatherCode <= 3) {
      return 'Parçalı bulutlu';
    }
    if (weatherCode >= 45 && weatherCode <= 48) {
      return 'Sisli / puslu';
    }
    if (weatherCode >= 71 && weatherCode <= 77) {
      return 'Karlı';
    }
    return 'Kapalı';
  }
}
