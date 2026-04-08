import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// İstanbul hava durumu verilerini tutar (saatlik + ana veri).
/// Uygulama açılışında otomatik çekilir; periyodik olarak güncellenir.
final istanbulWeatherProvider =
    AsyncNotifierProvider<IstanbulWeatherNotifier, IstanbulWeatherData>(
      IstanbulWeatherNotifier.new,
    );

class IstanbulWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel? current;
  final DateTime lastUpdated;

  const IstanbulWeatherData({
    required this.hourly,
    required this.current,
    required this.lastUpdated,
  });

  IstanbulWeatherData copyWith({
    List<HourlyWeatherModel>? hourly,
    WeatherModel? current,
    DateTime? lastUpdated,
  }) {
    return IstanbulWeatherData(
      hourly: hourly ?? this.hourly,
      current: current ?? this.current,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class IstanbulWeatherNotifier extends AsyncNotifier<IstanbulWeatherData> {
  Timer? _updateTimer;

  @override
  Future<IstanbulWeatherData> build() async {
    // İlk veri çekme
    final data = await _fetchAllData();

    // 30 dakikada bir otomatik güncelleme
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _autoRefresh();
    });

    // Timer'ı dispose etmek için
    ref.onDispose(() {
      _updateTimer?.cancel();
    });

    return data;
  }

  Future<IstanbulWeatherData> _fetchAllData() async {
    final hourly = await WeatherService.fetchIstanbulHourlyForecast();
    final current = await WeatherService.getWeatherByRegionKey('istanbul');
    return IstanbulWeatherData(
      hourly: hourly,
      current: current,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _autoRefresh() async {
    try {
      final newData = await _fetchAllData();
      state = AsyncData(newData);
    } catch (e) {
      // Otomatik güncelleme hatasında sessizce devam et
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAllData);
  }
}
