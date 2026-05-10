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

  /// Hava sekmesi yalnızca kıyı bölgeleri; mera detayında ilçe anahtarları kullanılır.
  String _coastalWeatherRegionKey() {
    final s = ref.read(selectedWeatherRegionProvider);
    if (s.startsWith('istanbul_ilce_')) return 'istanbul';
    return s;
  }

  void _normalizeSelectionOffIlceKeys() {
    final s = ref.read(selectedWeatherRegionProvider);
    if (!s.startsWith('istanbul_ilce_')) return;
    Future.microtask(() {
      try {
        ref.read(selectedWeatherRegionProvider.notifier).state = 'istanbul';
      } catch (_) {}
    });
  }

  @override
  Future<IstanbulWeatherData> build() async {
    _syncTimer?.cancel();
    ref.watch(selectedWeatherRegionProvider);
    _normalizeSelectionOffIlceKeys();

    final regionKey = _coastalWeatherRegionKey();
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
    final regionKey = _coastalWeatherRegionKey();
    try {
      if (!isIstanbulWallMinuteAtOrAfterSyncMark(DateTime.now().toUtc())) {
        _armNextScheduledSync();
        return;
      }
      await WeatherService.syncAllWeatherCacheRowsToDrift();
      final snap =
          await WeatherService.regionalFromDriftDisplayReady(regionKey);
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
    final utc = DateTime.now().toUtc();
    final gate = isIstanbulWallMinuteAtOrAfterSyncMark(utc);
    final hourStart = startOfCurrentIstanbulWallHourUtc(utc);

    RegionalWeatherData? snap =
        await WeatherService.regionalFromDriftDisplayReady(regionKey);

    if (snap == null) {
      snap = await WeatherService.syncRegionalWeatherFromSupabase(
        regionKey,
        fallbackToDrift: true,
      );
    } else if (gate && snap.current.fetchedAt.toUtc().isBefore(hourStart)) {
      final n = await WeatherService.syncAllWeatherCacheRowsToDrift();
      if (n > 0) {
        snap = await WeatherService.regionalFromDriftDisplayReady(regionKey);
      } else {
        final one = await WeatherService.syncRegionalWeatherFromSupabase(
          regionKey,
          fallbackToDrift: true,
        );
        if (one != null) snap = one;
      }
    }

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
    final regionKey = _coastalWeatherRegionKey();
    try {
      await WeatherService.syncAllWeatherCacheRowsToDrift();
      final snap =
          await WeatherService.regionalFromDriftDisplayReady(regionKey) ??
              await WeatherService.syncRegionalWeatherFromSupabase(
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
      final regionKey = _coastalWeatherRegionKey();
      final snap =
          await WeatherService.regionalFromDriftDisplayReady(regionKey);
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
