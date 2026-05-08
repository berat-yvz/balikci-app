import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/utils/fishing_score_engine.dart';
import 'package:balikci_app/core/utils/moon_phase_calculator.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';

/// Asset JSON'ları yükleyip motoru bir kez oluşturur.
final fishingScoreEngineProvider =
    FutureProvider<FishingScoreEngine>((ref) async {
  final rules = await rootBundle.loadString('assets/fishing/fishing_rules.json');
  final species =
      await rootBundle.loadString('assets/fishing/fish_species_istanbul.json');
  final moon =
      await rootBundle.loadString('assets/fishing/moon_phase_rules.json');
  return FishingScoreEngine.fromJsonStrings(rules, species, moon);
});

/// İstanbul hava paketi + güncel ay aydınlanması ile skor.
final fishingScoreProvider = Provider<AsyncValue<FishingScore>>((ref) {
  final engineAsync = ref.watch(fishingScoreEngineProvider);
  final weatherAsync = ref.watch(istanbulWeatherProvider);

  return engineAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (engine) {
      return weatherAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (pack) {
          final now = DateTime.now();
          final illum = MoonPhaseCalculator.getMoonIllumination(now);
          return AsyncValue.data(
            engine.calculate(pack.current, now, illum),
          );
        },
      );
    },
  );
});

/// Yarınki saatlik veriden türetilen temsili hava durumu (05:00–18:00 ortalaması).
/// Dalga yüksekliği maksimum alınır (güvenlik odaklı).
/// Basınç verisi saatlik bundle'da bulunmadığından null bırakılır.
final tomorrowAggregatedWeatherProvider =
    Provider<AsyncValue<WeatherModel?>>((ref) {
  final weatherAsync = ref.watch(istanbulWeatherProvider);
  return weatherAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (pack) => AsyncValue.data(_aggregateTomorrowWeather(pack.hourly)),
  );
});

/// Yarın için balıkçılık skoru — saatlik hava verisinden türetilir.
/// Saatlik veri yoksa (Drift offline cache) null döner.
final tomorrowFishingScoreProvider =
    Provider<AsyncValue<FishingScore?>>((ref) {
  final engineAsync = ref.watch(fishingScoreEngineProvider);
  final tomorrowWeatherAsync = ref.watch(tomorrowAggregatedWeatherProvider);

  return engineAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (engine) {
      return tomorrowWeatherAsync.when(
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
        data: (weather) {
          if (weather == null) return const AsyncValue.data(null);
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final illum = MoonPhaseCalculator.getMoonIllumination(tomorrow);
          return AsyncValue.data(engine.calculate(weather, tomorrow, illum));
        },
      );
    },
  );
});

// ── Yardımcı fonksiyonlar ────────────────────────────────────────────────────

WeatherModel? _aggregateTomorrowWeather(List<HourlyWeatherModel> hourly) {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

  final hours = hourly.where((h) {
    final hDate = DateTime(h.time.year, h.time.month, h.time.day);
    return hDate == tomorrowDate && h.time.hour >= 5 && h.time.hour <= 18;
  }).toList();

  if (hours.isEmpty) return null;

  final n = hours.length.toDouble();
  final avgTemp =
      hours.map((h) => h.temperature).reduce((a, b) => a + b) / n;
  final avgWind =
      hours.map((h) => h.windspeed).reduce((a, b) => a + b) / n;
  final avgPrecip =
      hours.map((h) => h.precipitation).reduce((a, b) => a + b) / n;

  final waveSamples = hours.where((h) => h.waveHeight != null).toList();
  final maxWave = waveSamples.isEmpty
      ? null
      : waveSamples
          .map((h) => h.waveHeight!)
          .reduce((a, b) => a > b ? a : b);

  final sstSamples =
      hours.where((h) => h.seaSurfaceTemperature != null).toList();
  final avgSst = sstSamples.isEmpty
      ? null
      : sstSamples
              .map((h) => h.seaSurfaceTemperature!)
              .reduce((a, b) => a + b) /
          sstSamples.length;

  return WeatherModel(
    id: 'tomorrow_forecast',
    lat: 0,
    lng: 0,
    dataJson: null,
    temperature: avgTemp,
    windspeed: avgWind,
    windDirection: _circularAvgWindDir(hours),
    waveHeight: maxWave,
    seaSurfaceTemperature: avgSst,
    precipitation: avgPrecip,
    humidity: null,
    visibilityKm: null,
    cloudCover: null,
    pressureHpa: null,
    pressureHpa3hAgo: null,
    weatherCode: _modalWeatherCode(hours),
    fishingSummary: null,
    fetchedAt: DateTime.now(),
    regionKey: null,
  );
}

int _modalWeatherCode(List<HourlyWeatherModel> hours) {
  if (hours.isEmpty) return 0;
  final freq = <int, int>{};
  for (final h in hours) {
    freq[h.weatherCode] = (freq[h.weatherCode] ?? 0) + 1;
  }
  return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

int? _circularAvgWindDir(List<HourlyWeatherModel> hours) {
  final dirs = hours
      .where((h) => h.windDirection != null)
      .map((h) => h.windDirection!)
      .toList();
  if (dirs.isEmpty) return null;
  var sinSum = 0.0;
  var cosSum = 0.0;
  for (final d in dirs) {
    sinSum += math.sin(d * math.pi / 180);
    cosSum += math.cos(d * math.pi / 180);
  }
  final angle = math.atan2(sinSum, cosSum) * 180 / math.pi;
  return ((angle + 360) % 360).round();
}
