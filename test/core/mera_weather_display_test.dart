import 'package:balikci_app/core/utils/mera_weather_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WMO yağış kodu → Yağışlı', () {
    expect(
      MeraWeatherDisplay.skyConditionFromWmo(weatherCode: 61, precipitationMm: 0),
      'Yağışlı',
    );
  });

  test('Açık gökyüzü', () {
    expect(
      MeraWeatherDisplay.skyConditionFromWmo(weatherCode: 0, precipitationMm: 0),
      'Açık',
    );
  });

  test('Hafif yağış mm ile', () {
    expect(
      MeraWeatherDisplay.skyConditionFromWmo(weatherCode: 1, precipitationMm: 0.2),
      'Yağışlı',
    );
  });
}
