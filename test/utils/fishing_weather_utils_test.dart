import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Test için WeatherModel üretici yardımcısı.
WeatherModel _makeWeather({
  double temp = 20,
  double wind = 10,
  int? weatherCode,
  String? fishingSummary,
}) {
  return WeatherModel(
    id: 'test',
    lat: 41.0,
    lng: 28.0,
    dataJson: null,
    temperature: temp,
    windspeed: wind,
    windDirection: null,
    waveHeight: null,
    seaSurfaceTemperature: null,
    precipitation: null,
    humidity: null,
    visibilityKm: null,
    cloudCover: null,
    weatherCode: weatherCode,
    fishingSummary: fishingSummary,
    fetchedAt: DateTime(2025),
    regionKey: 'test',
  );
}

void main() {
  group('FishingWeatherUtils.getSummary', () {
    test('fishingSummary varsa direkt döner', () {
      final w = _makeWeather(fishingSummary: 'Test özet');
      expect(FishingWeatherUtils.getSummary(w), 'Test özet');
    });

    test('fishingSummary null → client-side kural çalışır', () {
      final w = _makeWeather(temp: 20, wind: 10, weatherCode: 800);
      final summary = FishingWeatherUtils.getSummary(w);
      expect(summary, isNotEmpty);
    });

    test('rüzgar > 40 → tehlike uyarısı', () {
      final w = _makeWeather(wind: 45);
      expect(FishingWeatherUtils.getSummary(w), contains('patlak'));
    });

    test('gök gürültüsü (200-299) → fırtına mesajı', () {
      final w = _makeWeather(weatherCode: 212);
      expect(FishingWeatherUtils.getSummary(w), contains('Fırtına'));
    });

    test('sis (700-799) → sis uyarısı', () {
      final w = _makeWeather(weatherCode: 741);
      expect(FishingWeatherUtils.getSummary(w), contains('Sis'));
    });

    test('yağmur (500-599) + soğuk → istavrit mesajı', () {
      final w = _makeWeather(temp: 12, wind: 15, weatherCode: 502);
      expect(FishingWeatherUtils.getSummary(w), contains('istavrit'));
    });

    test('yağmur (500-599) + ılık → kıyı mesajı', () {
      final w = _makeWeather(temp: 18, wind: 10, weatherCode: 501);
      expect(FishingWeatherUtils.getSummary(w), contains('kıyı'));
    });

    test('ideal lüfer koşulları', () {
      final w = _makeWeather(temp: 20, wind: 12, weatherCode: 800);
      expect(FishingWeatherUtils.getSummary(w), contains('lüfer'));
    });

    test('sıcak ve sakin → derin su mesajı', () {
      final w = _makeWeather(temp: 28, wind: 5);
      expect(FishingWeatherUtils.getSummary(w), contains('derin'));
    });

    test('serin hava → çipura/levrek mesajı', () {
      final w = _makeWeather(temp: 13, wind: 15);
      expect(FishingWeatherUtils.getSummary(w), contains('çipura'));
    });
  });

  group('FishingWeatherUtils.getFishingScore', () {
    test('ideal koşullar → yüksek skor (>=75)', () {
      final w = _makeWeather(temp: 20, wind: 10, weatherCode: 800);
      final score = FishingWeatherUtils.getFishingScore(w);
      expect(score, greaterThanOrEqualTo(75));
    });

    test('fırtına → düşük skor', () {
      final w = _makeWeather(wind: 45, weatherCode: 212);
      final score = FishingWeatherUtils.getFishingScore(w);
      expect(score, lessThan(25));
    });

    test('skor her zaman 0-100 aralığında', () {
      final extremeCases = [
        _makeWeather(wind: 100, weatherCode: 212),
        _makeWeather(wind: 0, temp: 22, weatherCode: 800),
      ];
      for (final w in extremeCases) {
        final score = FishingWeatherUtils.getFishingScore(w);
        expect(score, inInclusiveRange(0, 100));
      }
    });

    test('rüzgar > 40 → 40 puan düşüş', () {
      final baseline = FishingWeatherUtils.getFishingScore(
        _makeWeather(wind: 10),
      );
      final withWind = FishingWeatherUtils.getFishingScore(
        _makeWeather(wind: 45),
      );
      expect(baseline - withWind, greaterThanOrEqualTo(40));
    });
  });

  group('FishingWeatherUtils.getScoreEmoji', () {
    test('75+ → yeşil', () {
      expect(FishingWeatherUtils.getScoreEmoji(75), '🟢');
      expect(FishingWeatherUtils.getScoreEmoji(100), '🟢');
    });

    test('50-74 → sarı', () {
      expect(FishingWeatherUtils.getScoreEmoji(50), '🟡');
      expect(FishingWeatherUtils.getScoreEmoji(74), '🟡');
    });

    test('25-49 → turuncu', () {
      expect(FishingWeatherUtils.getScoreEmoji(25), '🟠');
      expect(FishingWeatherUtils.getScoreEmoji(49), '🟠');
    });

    test('0-24 → kırmızı', () {
      expect(FishingWeatherUtils.getScoreEmoji(0), '🔴');
      expect(FishingWeatherUtils.getScoreEmoji(24), '🔴');
    });
  });

  group('FishingWeatherUtils.getScoreLabel', () {
    test('75+ → Harika', () {
      expect(FishingWeatherUtils.getScoreLabel(80), 'Harika');
    });

    test('50-74 → İyi', () {
      expect(FishingWeatherUtils.getScoreLabel(60), 'İyi');
    });

    test('25-49 → Orta', () {
      expect(FishingWeatherUtils.getScoreLabel(40), 'Orta');
    });

    test('0-24 → Kötü', () {
      expect(FishingWeatherUtils.getScoreLabel(10), 'Kötü');
    });
  });
}
