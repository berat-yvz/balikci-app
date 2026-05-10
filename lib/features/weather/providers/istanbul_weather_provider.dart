import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/core/utils/weather_tr_schedule.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Seçili hava bölgesi anahtarı — varsayılan İstanbul.
final selectedWeatherRegionProvider =
    StateProvider<String>((ref) => 'istanbul');

/// Hava durumu sekmesi — ağ: yalnızca İstanbul yereli **her saat :02** +
/// ilk açılışta önbellek boşsa tek `weather_cache` okuması.
/// Diğer zamanlarda yalnızca Drift.
final istanbulWeatherProvider =
    AsyncNotifierProvider<IstanbulWeatherNotifier, IstanbulWeatherData>(
      IstanbulWeatherNotifier.new,
    );

class IstanbulWeatherData {
  final List<HourlyWeatherModel> hourly;
  final WeatherModel current;
  final double lat;
  final double lng;

  /// true ise bu paket Drift'ten (veya ağsız yoldan) geldi.
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
  Timer? _syncTimer;

  @override
  Future<IstanbulWeatherData> build() async {
    _syncTimer?.cancel();
    ref.watch(selectedWeatherRegionProvider);

    final regionKey = ref.read(selectedWeatherRegionProvider);
    final data = await _initialLoad(regionKey);
    _armNextScheduledSync();

    ref.onDispose(() => _syncTimer?.cancel());
    return data;
  }

  void _armNextScheduledSync() {
    _syncTimer?.cancel();
    final utcNow = DateTime.now().toUtc();
    final nextUtc = nextUtcInstantForIstanbulWallMinute2(utcNow);
    var delay = nextUtc.difference(DateTime.now().toUtc());
    if (delay.isNegative) delay = Duration.zero;
    _syncTimer = Timer(delay, () {
      unawaited(_runScheduledSupabaseSyncThenReschedule());
    });
  }

  /// Planlı saat :02 — `weather_cache` tek okuma (sunucu saat başı doldurmuş olmalı).
  Future<void> _runScheduledSupabaseSyncThenReschedule() async {
    final regionKey = ref.read(selectedWeatherRegionProvider);
    try {
      final snap = await WeatherService.syncRegionalWeatherFromSupabase(
        regionKey,
        fallbackToDrift: true,
      );
      if (snap == null) {
        _armNextScheduledSync();
        return;
      }
      final prev = state.asData?.value;
      if (snap.isFromCache) {
        if (prev != null && !prev.isFromCache) {
          _armNextScheduledSync();
          return;
        }
      }
      try {
        state = AsyncData(_toUi(snap));
      } catch (_) {
        // Provider dispose olduysa yoksay.
      }
    } catch (e, st) {
      debugPrint('[IstanbulWeatherNotifier] Planlı senkron: $e\n$st');
    }
    try {
      _armNextScheduledSync();
    } catch (_) {}
  }

  Future<IstanbulWeatherData> _initialLoad(String regionKey) async {
    var snap = await WeatherService.loadRegionalWeatherFromDrift(regionKey);
    snap ??= await WeatherService.syncRegionalWeatherFromSupabase(
      regionKey,
      fallbackToDrift: true,
    );
    if (snap == null) {
      throw StateError(
        'Hava önbelleği boş. Sunucu weather-cache (saat başı) ve '
        'bir sonraki yerel güncelleme (:02) bekleniyor.',
      );
    }
    return _toUi(snap);
  }

  IstanbulWeatherData _toUi(RegionalWeatherData snap) => IstanbulWeatherData(
        hourly: snap.hourly,
        current: snap.current,
        lat: snap.lat,
        lng: snap.lng,
        isFromCache: snap.isFromCache,
      );

  /// Aşağı kaydırma: `weather_cache` tek okuma + Drift (Edge/Open-Meteo tetiklenmez).
  Future<void> refreshFromServer() async {
    final regionKey = ref.read(selectedWeatherRegionProvider);
    try {
      final snap = await WeatherService.syncRegionalWeatherFromSupabase(
        regionKey,
        fallbackToDrift: true,
      );
      if (snap != null) {
        state = AsyncData(_toUi(snap));
        return;
      }
    } catch (e, st) {
      debugPrint('[IstanbulWeatherNotifier] Sunucu yenileme: $e\n$st');
    }
    await reloadFromDriftOnly();
  }

  /// Uygulama öne gelince — ağ yok.
  Future<void> pullLatestSilently() async {
    await reloadFromDriftOnly();
  }

  Future<void> reloadFromDriftOnly() async {
    try {
      final regionKey = ref.read(selectedWeatherRegionProvider);
      final snap = await WeatherService.loadRegionalWeatherFromDrift(regionKey);
      if (snap == null) return;
      final prev = state.asData?.value;
      if (snap.isFromCache) {
        if (prev != null && !prev.isFromCache) return;
      }
      state = AsyncData(_toUi(snap));
    } catch (e, st) {
      debugPrint('[IstanbulWeatherNotifier] Drift yenileme: $e\n$st');
    }
  }
}
