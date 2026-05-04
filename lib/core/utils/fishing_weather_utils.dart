import 'package:balikci_app/data/models/weather_model.dart';

/// Balıkçı dili hava çevirisi — MVP_PLAN.md M-04 kural tablosu.
class FishingWeatherUtils {
  FishingWeatherUtils._();

  /// WeatherModel'den balıkçı dili özeti üretir.
  /// Edge Function'dan gelen fishingSummary varsa onu döner,
  /// yoksa client-side kural tablosunu çalıştırır.
  static String getSummary(WeatherModel weather) {
    if (weather.fishingSummary != null && weather.fishingSummary!.isNotEmpty) {
      return weather.fishingSummary!;
    }
    return _clientSideRule(weather);
  }

  /// Hava durumuna göre balıkçılık skoru (0–100).
  static int getFishingScore(WeatherModel weather) {
    int score = 70; // başlangıç

    // Rüzgar etkisi
    final wind = weather.windKmh;
    if (wind > 40) {
      score -= 40;
    } else if (wind > 25) {
      score -= 20;
    } else if (wind < 15) {
      score += 10;
    }

    // Sıcaklık etkisi
    final temp = weather.tempCelsius;
    if (temp >= 16 && temp <= 24) {
      score += 15;
    } else if (temp > 28) {
      score -= 10;
    } else if (temp < 8) {
      score -= 15;
    }

    // Hava kodu etkisi — Open-Meteo WMO kodları (0-99)
    final code = weather.weatherCode ?? 0;
    if (code >= 95 && code <= 99) {
      score -= 30; // gök gürültüsü / şiddetli fırtına
    } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      score -= 10; // yağmur / sağanak
    } else if (code >= 45 && code <= 48) {
      score -= 15; // sis / kırağı
    } else if (code == 0) {
      score += 10; // tamamen açık
    } else if (code >= 1 && code <= 3) {
      score += 5; // az-orta bulutlu
    }

    return score.clamp(0, 100);
  }

  /// Skora göre emoji döner.
  static String getScoreEmoji(int score) {
    if (score >= 75) return '🟢';
    if (score >= 50) return '🟡';
    if (score >= 25) return '🟠';
    return '🔴';
  }

  /// Skora göre kısa etiket.
  static String getScoreLabel(int score) {
    if (score >= 75) return 'Harika';
    if (score >= 50) return 'İyi';
    if (score >= 25) return 'Orta';
    return 'Kötü';
  }

  static String _clientSideRule(WeatherModel weather) {
    final wind = weather.windKmh;
    final temp = weather.tempCelsius;
    final code = weather.weatherCode ?? 0;

    // Tehlikeli koşullar
    if (wind > 40) return 'Deniz patlak, çıkma ⚠️';
    if (code >= 95 && code <= 99) return 'Fırtına var, bugün balık yok ⛈️';
    if (code >= 45 && code <= 48) return 'Sis var, tekneyle dikkatli ol 🌫️';

    // Yağmur koşulları (WMO: hafif/orta yağmur 61-67, sağanak 80-82)
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      if (temp < 15) return 'Soğuk ve yağışlı, istavrit günü 🌧️';
      return 'Hafif yağmur, kıyıdan oltaya çık 🎣';
    }

    // İdeal koşullar
    if (wind < 15 && temp >= 18 && temp <= 24) {
      return 'Bugün hava tam lüfer havası ✓';
    }
    if (wind < 10 && temp > 24) return 'Sıcak ve sakin, derin sularda ara 🐟';
    if (temp >= 10 && temp < 16 && wind < 20) {
      return 'Serin hava, çipura ve levrek aktif 🎣';
    }

    // Genel değerlendirme
    if (wind < 20 && code == 0) return 'Açık hava, balıkçılık için uygun ✓';
    if (wind >= 20 && wind <= 35) return 'Rüzgarlı, kıyıda kalmak daha iyi ⚠️';

    return 'Hava verisi güncellendi, koşulları değerlendir';
  }
}
