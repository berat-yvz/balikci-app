import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/utils/fishing_score_engine.dart';
import 'package:balikci_app/core/utils/moon_phase_calculator.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';

/// Asset JSON’ları yükleyip motoru bir kez oluşturur.
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
