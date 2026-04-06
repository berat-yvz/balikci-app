import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';

/// İstanbul saatlik hava tahminini tutar.
/// Uygulama açılışında otomatik çekilir; refresh() ile elle yenilenebilir.
final istanbulWeatherProvider =
    AsyncNotifierProvider<IstanbulWeatherNotifier, List<HourlyWeatherModel>>(
  IstanbulWeatherNotifier.new,
);

class IstanbulWeatherNotifier
    extends AsyncNotifier<List<HourlyWeatherModel>> {
  @override
  Future<List<HourlyWeatherModel>> build() async {
    return WeatherService.fetchIstanbulHourlyForecast();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => WeatherService.fetchIstanbulHourlyForecast(),
    );
  }
}
