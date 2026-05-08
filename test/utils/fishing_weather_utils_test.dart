import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/weather_model.dart';

WeatherModel _makeWeather({
  double temp = 20,
  double wind = 10,
  int? weatherCode,
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
    fishingSummary: null,
    fetchedAt: DateTime(2025),
    regionKey: 'test',
  );
}

void main() {
  group('FishingWeatherUtils.getFishingScore', () {
    test('ideal kosullar yuksek skor (>=75)', () {
      // WMO 0 = tamamen açık (+10), wind=10 < 15 (+10), temp=20 16-24 aralığı (+15)
      final w = _makeWeather(temp: 20, wind: 10, weatherCode: 0);
      final score = FishingWeatherUtils.getFishingScore(w);
      expect(score, greaterThanOrEqualTo(75));
    });

    test('firtina ve sert ruzgar dusuk skor (<25)', () {
      // WMO 99 = şiddetli gök gürültülü fırtına (-30), wind=45 > 40 (-40)
      final w = _makeWeather(wind: 45, weatherCode: 99);
      final score = FishingWeatherUtils.getFishingScore(w);
      expect(score, lessThan(25));
    });

    test('skor her zaman 0-100 araliginda', () {
      final extremeCases = [
        _makeWeather(wind: 100, weatherCode: 99),
        _makeWeather(wind: 0, temp: 22, weatherCode: 0),
      ];
      for (final w in extremeCases) {
        final score = FishingWeatherUtils.getFishingScore(w);
        expect(score, inInclusiveRange(0, 100));
      }
    });

    test('ruzgar > 40 baseline ile karsilastirildiginda en az 40 puan dusus', () {
      final baseline = FishingWeatherUtils.getFishingScore(
        _makeWeather(wind: 10),
      );
      final withWind = FishingWeatherUtils.getFishingScore(
        _makeWeather(wind: 45),
      );
      expect(baseline - withWind, greaterThanOrEqualTo(40));
    });
  });
}
