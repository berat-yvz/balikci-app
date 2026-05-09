import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Seçili hava bölgesi anahtarı — varsayılan İstanbul.
final selectedWeatherRegionProvider =
    StateProvider<String>((ref) => 'istanbul');

/// Bölge anahtarı → Türkçe görünen ad (ekleme sırası korunur).
const Map<String, String> weatherRegionDisplayNames = {
  'istanbul':  'İstanbul',
  'izmir':     'İzmir',
  'antalya':   'Antalya',
  'trabzon':   'Trabzon',
  'canakkale': 'Çanakkale',
  'bodrum':    'Bodrum',
  'fethiye':   'Fethiye',
  'sinop':     'Sinop',
  'samsun':    'Samsun',
  'mersin':    'Mersin',
  'mugla':     'Muğla',
  'balikesir': 'Balıkesir',
};

/// Hava durumu sekmesi — tek kaynak: Supabase `weather_cache`.
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

  /// true ise Supabase erişilemedi, Drift local cache'ten yüklendi.
  /// Saatlik veri boş, saatlik tahmin gösterilemez.
  final bool isFromCache;

  const IstanbulWeatherData({
    required this.hourly,
    required this.current,
    required this.lat,
    required this.lng,
    this.isFromCache = false,
  });
}

class IstanbulWeatherNotifier extends AsyncNotifier<IstanbulWeatherData> {
  Timer? _pollTimer;

  @override
  Future<IstanbulWeatherData> build() async {
    final regionKey = ref.watch(selectedWeatherRegionProvider);
    _pollTimer?.cancel();
    final data = await _loadFromSupabase(regionKey);
    _scheduleHourlyPoll(regionKey);
    ref.onDispose(() => _pollTimer?.cancel());
    return data;
  }

  void _scheduleHourlyPoll(String regionKey) {
    _pollTimer?.cancel();
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    _pollTimer = Timer(nextHour.difference(now), () {
      unawaited(_silentReload(regionKey));
      _scheduleHourlyPoll(regionKey);
    });
  }

  Future<void> _silentReload(String regionKey) async {
    try {
      final snap =
          await WeatherService.fetchRegionalWeatherFromSupabase(regionKey);
      // Drift cache verisiyle (isFromCache=true) iyi online veriyi ezme.
      // Internet kesilince Drift fallback devreye girer ama eski doğru
      // skoru bozmaması için state güncellenmez; mevcut veri korunur.
      if (snap == null || snap.isFromCache) return;
      state = AsyncData(IstanbulWeatherData(
        hourly: snap.hourly,
        current: snap.current,
        lat: snap.lat,
        lng: snap.lng,
      ));
    } catch (e, st) {
      debugPrint('[IstanbulWeatherProvider] Sessiz yenileme hatası: $e\n$st');
    }
  }

  Future<IstanbulWeatherData> _loadFromSupabase(String regionKey) async {
    final snap =
        await WeatherService.fetchRegionalWeatherFromSupabase(regionKey);
    if (snap == null) {
      throw StateError(
          'Hava önbelleği boş. Sunucu weather-cache cron kontrol edin.');
    }
    return IstanbulWeatherData(
      hourly: snap.hourly,
      current: snap.current,
      lat: snap.lat,
      lng: snap.lng,
      isFromCache: snap.isFromCache,
    );
  }
}
