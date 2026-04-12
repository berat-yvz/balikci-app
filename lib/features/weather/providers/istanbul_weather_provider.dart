import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Hava durumu sekmesi — tek kaynak: Supabase `weather_cache` (İstanbul bölgesi).
/// Sunucu her saat başı Open-Meteo verisini yazar; istemci yenileme göstermez / çekmez.
///
/// Provider adı geriye uyumluluk için korunmuştur.
final istanbulWeatherProvider =
    AsyncNotifierProvider<IstanbulWeatherNotifier, IstanbulWeatherData>(
      IstanbulWeatherNotifier.new,
    );

class IstanbulWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel current;
  final double lat;
  final double lng;

  const IstanbulWeatherData({
    required this.hourly,
    required this.current,
    required this.lat,
    required this.lng,
  });
}

class IstanbulWeatherNotifier extends AsyncNotifier<IstanbulWeatherData> {
  static const String _regionKey = 'istanbul';

  Timer? _pollTimer;

  @override
  Future<IstanbulWeatherData> build() async {
    final data = await _loadFromSupabase();
    _scheduleHourlySupabasePoll();
    ref.onDispose(() => _pollTimer?.cancel());
    return data;
  }

  /// Bir sonraki tam saat başında yalnızca Supabase’ten tekrar oku (Open-Meteo yok).
  void _scheduleHourlySupabasePoll() {
    _pollTimer?.cancel();
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    _pollTimer = Timer(nextHour.difference(now), () {
      unawaited(_silentReload());
      _scheduleHourlySupabasePoll();
    });
  }

  Future<void> _silentReload() async {
    try {
      final next = await _loadFromSupabase();
      state = AsyncData(next);
    } catch (_) {
      // Mevcut veriyi koru
    }
  }

  Future<IstanbulWeatherData> _loadFromSupabase() async {
    final snap =
        await WeatherService.fetchRegionalWeatherFromSupabase(_regionKey);
    if (snap == null) {
      throw StateError('Hava önbelleği boş. Sunucu weather-cache cron kontrol edin.');
    }
    return IstanbulWeatherData(
      hourly: snap.hourly,
      current: snap.current,
      lat: snap.lat,
      lng: snap.lng,
    );
  }
}
