/// Balık ansiklopedisi — tek kayıt (JSON `fish` öğesi).
class FishEncyclopediaEntry {
  final String id;
  final String name;
  final String scientificName;
  final String category;
  final String emoji;
  final List<String> seasons;
  final List<int> bestMonths;
  final List<String> habitats;
  final List<String> baits;
  final List<String> techniques;
  final int? minLegalSizeCm;
  final double avgWeightKg;
  final String difficulty;
  final String funFact;
  final List<String> tips;

  const FishEncyclopediaEntry({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.category,
    required this.emoji,
    required this.seasons,
    required this.bestMonths,
    required this.habitats,
    required this.baits,
    required this.techniques,
    required this.minLegalSizeCm,
    required this.avgWeightKg,
    required this.difficulty,
    required this.funFact,
    required this.tips,
  });

  factory FishEncyclopediaEntry.fromJson(Map<String, dynamic> json) {
    return FishEncyclopediaEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      scientificName: json['scientific_name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🐟',
      seasons: (json['seasons'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      bestMonths: (json['best_months'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList(growable: false) ??
          const [],
      habitats: (json['habitats'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      baits: (json['baits'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      techniques: (json['techniques'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      minLegalSizeCm: (json['min_legal_size_cm'] as num?)?.toInt(),
      avgWeightKg: (json['avg_weight_kg'] as num?)?.toDouble() ?? 0,
      difficulty: json['difficulty'] as String? ?? 'orta',
      funFact: json['fun_fact'] as String? ?? '',
      tips: (json['tips'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }
}
