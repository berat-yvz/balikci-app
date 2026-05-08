import 'package:balikci_app/data/models/weather_model.dart';

/// Balıkçı hava skoru yardımcısı — weather_card ve weather_screen hata fallback'i.
/// Ana skor motoru için bkz. FishingScoreEngine.
class FishingWeatherUtils {
  FishingWeatherUtils._();

  /// Hava durumuna göre basit balıkçılık skoru (0–100).
  /// FishingScoreEngine yüklenemediğinde fallback olarak kullanılır.
  static int getFishingScore(WeatherModel weather) {
    int score = 70;

    final wind = weather.windKmh;
    if (wind > 40) {
      score -= 40;
    } else if (wind > 25) {
      score -= 20;
    } else if (wind < 15) {
      score += 10;
    }

    final temp = weather.tempCelsius;
    if (temp >= 16 && temp <= 24) {
      score += 15;
    } else if (temp > 28) {
      score -= 10;
    } else if (temp < 8) {
      score -= 15;
    }

    // Open-Meteo WMO kodları
    final code = weather.weatherCode ?? 0;
    if (code >= 95 && code <= 99) {
      score -= 30;
    } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      score -= 10;
    } else if (code >= 45 && code <= 48) {
      score -= 15;
    } else if (code == 0) {
      score += 10;
    } else if (code >= 1 && code <= 3) {
      score += 5;
    }

    return score.clamp(0, 100);
  }
}
