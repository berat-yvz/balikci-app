import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentHourFromHourly — gelecekteki ilk slot', () {
    final now = DateTime.now();
    final slot = DateTime(now.year, now.month, now.day, now.hour);
    final h0 = HourlyWeatherModel(
      time: slot.subtract(const Duration(hours: 2)),
      temperature: 10,
      windspeed: 5,
      precipitation: 0,
      weatherCode: 0,
    );
    final h1 = HourlyWeatherModel(
      time: slot,
      temperature: 12,
      windspeed: 6,
      precipitation: 0,
      weatherCode: 1,
    );
    final h2 = HourlyWeatherModel(
      time: slot.add(const Duration(hours: 1)),
      temperature: 13,
      windspeed: 7,
      precipitation: 0,
      weatherCode: 2,
    );
    final pick = WeatherService.currentHourFromHourly([h0, h1, h2]);
    expect(pick?.time, h1.time);
  });
}
