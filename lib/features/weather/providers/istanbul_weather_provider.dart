import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Kullanıcı konumuna göre hava durumu verileri.
/// GPS alınamazsa İstanbul fallback kullanılır.
///
/// Provider adı geriye uyumluluk için korunmuştur.
final istanbulWeatherProvider =
    AsyncNotifierProvider<IstanbulWeatherNotifier, IstanbulWeatherData>(
      IstanbulWeatherNotifier.new,
    );

class IstanbulWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel? current;
  final DateTime lastUpdated;

  /// Gerçek konumu temsil eder (GPS veya fallback).
  final double lat;
  final double lng;

  /// GPS başarılı mıydı?
  final bool gpsUsed;

  const IstanbulWeatherData({
    required this.hourly,
    required this.current,
    required this.lastUpdated,
    required this.lat,
    required this.lng,
    required this.gpsUsed,
  });

  IstanbulWeatherData copyWith({
    List<HourlyWeatherModel>? hourly,
    WeatherModel? current,
    DateTime? lastUpdated,
    double? lat,
    double? lng,
    bool? gpsUsed,
  }) {
    return IstanbulWeatherData(
      hourly: hourly ?? this.hourly,
      current: current ?? this.current,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      gpsUsed: gpsUsed ?? this.gpsUsed,
    );
  }
}

class IstanbulWeatherNotifier extends AsyncNotifier<IstanbulWeatherData> {
  static const double _fallbackLat = 41.0082;
  static const double _fallbackLng = 28.9784;

  Timer? _updateTimer;

  @override
  Future<IstanbulWeatherData> build() async {
    final data = await _fetchAllData();

    // 30 dakikada bir otomatik güncelleme
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _autoRefresh();
    });

    ref.onDispose(() => _updateTimer?.cancel());
    return data;
  }

  Future<IstanbulWeatherData> _fetchAllData() async {
    // Cihaz konumunu al; başarısız olursa fallback
    Position? pos;
    bool gpsUsed = false;
    try {
      pos = await LocationService.getCurrentPosition();
      gpsUsed = pos != null;
    } catch (_) {}

    final lat = pos?.latitude ?? _fallbackLat;
    final lng = pos?.longitude ?? _fallbackLng;

    final hourly = await WeatherService.fetchHourlyForecast(lat: lat, lng: lng);
    final current = await WeatherService.getWeatherForLocation(lat: lat, lng: lng);

    return IstanbulWeatherData(
      hourly: hourly,
      current: current,
      lastUpdated: DateTime.now(),
      lat: lat,
      lng: lng,
      gpsUsed: gpsUsed,
    );
  }

  Future<void> _autoRefresh() async {
    try {
      final newData = await _fetchAllData();
      state = AsyncData(newData);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAllData);
  }
}
