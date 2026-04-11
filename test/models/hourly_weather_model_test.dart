import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';

HourlyWeatherModel _make({int weatherCode = 0, double? currentDirection}) =>
    HourlyWeatherModel(
      time: DateTime(2025, 6, 1, 12),
      temperature: 22.0,
      windspeed: 15.0,
      precipitation: 0.0,
      weatherCode: weatherCode,
      currentDirection: currentDirection,
    );

void main() {
  group('HourlyWeatherModel.weatherEmoji', () {
    test('kod 0 → güneş ☀️', () {
      expect(_make(weatherCode: 0).weatherEmoji, '☀️');
    });

    test('kod 1-3 → parçalı bulutlu ⛅', () {
      expect(_make(weatherCode: 1).weatherEmoji, '⛅');
      expect(_make(weatherCode: 3).weatherEmoji, '⛅');
    });

    test('kod 4-49 → sis/duman 🌫️', () {
      expect(_make(weatherCode: 10).weatherEmoji, '🌫️');
      expect(_make(weatherCode: 49).weatherEmoji, '🌫️');
    });

    test('kod 50-69 → yağmurlu 🌧️', () {
      expect(_make(weatherCode: 51).weatherEmoji, '🌧️');
      expect(_make(weatherCode: 69).weatherEmoji, '🌧️');
    });

    test('kod 70-79 → karlı ❄️', () {
      expect(_make(weatherCode: 70).weatherEmoji, '❄️');
      expect(_make(weatherCode: 79).weatherEmoji, '❄️');
    });

    test('kod 80-99 → fırtına ⛈️', () {
      expect(_make(weatherCode: 80).weatherEmoji, '⛈️');
      expect(_make(weatherCode: 99).weatherEmoji, '⛈️');
    });

    test('kod 100+ → termometre 🌡️', () {
      expect(_make(weatherCode: 100).weatherEmoji, '🌡️');
    });
  });

  group('HourlyWeatherModel.currentDirectionArrow', () {
    test('null → null döner', () {
      expect(_make().currentDirectionArrow, isNull);
    });

    test('0° → kuzey ↑', () {
      expect(_make(currentDirection: 0).currentDirectionArrow, '↑');
    });

    test('90° → doğu →', () {
      expect(_make(currentDirection: 90).currentDirectionArrow, '→');
    });

    test('180° → güney ↓', () {
      expect(_make(currentDirection: 180).currentDirectionArrow, '↓');
    });

    test('270° → batı ←', () {
      expect(_make(currentDirection: 270).currentDirectionArrow, '←');
    });

    test('360° → kuzey ↑ (sıfıra sarılır)', () {
      expect(_make(currentDirection: 360).currentDirectionArrow, '↑');
    });

    test('45° → kuzeydoğu ↗', () {
      expect(_make(currentDirection: 45).currentDirectionArrow, '↗');
    });
  });

  group('HourlyWeatherModel.fromOpenMeteo', () {
    test('datetime string doğru parse edilir', () {
      final m = HourlyWeatherModel.fromOpenMeteo(
        timeStr: '2025-06-01T14:00',
        temperature: 25.0,
        windspeed: 20.0,
        precipitation: 0.0,
        weatherCode: 0,
      );
      expect(m.time.hour, 14);
      expect(m.time.day, 1);
    });

    test('opsiyonel alanlar null kalır', () {
      final m = HourlyWeatherModel.fromOpenMeteo(
        timeStr: '2025-06-01T10:00',
        temperature: 18.0,
        windspeed: 10.0,
        precipitation: 0.0,
        weatherCode: 0,
      );
      expect(m.cloudCover, isNull);
      expect(m.waveHeight, isNull);
      expect(m.currentVelocity, isNull);
    });
  });
}
