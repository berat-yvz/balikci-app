import 'package:flutter/foundation.dart';

@immutable
class FishingScore {
  /// 0–100
  final int score;

  /// "Mükemmel", "İyi", "Orta", "Zayıf", "Kötü"
  final String label;

  /// "green", "teal", "amber", "orange", "red"
  final String labelColor;

  /// Kısa açıklama, maks 60 karakter
  final String summary;

  /// Tetiklenen kural mesajları (en fazla 3)
  final List<String> activeMessages;

  final List<FishSpeciesTip> suggestedSpecies;

  /// "rising_fast"|"rising"|"stable"|"falling"|"falling_fast" veya veri yoksa null
  final String? pressureTrend;

  const FishingScore({
    required this.score,
    required this.label,
    required this.labelColor,
    required this.summary,
    required this.activeMessages,
    required this.suggestedSpecies,
    this.pressureTrend,
  });
}

@immutable
class FishSpeciesTip {
  final String id;
  final String name;
  final bool isInSeason;
  final String? tip;

  const FishSpeciesTip({
    required this.id,
    required this.name,
    required this.isInSeason,
    this.tip,
  });
}
