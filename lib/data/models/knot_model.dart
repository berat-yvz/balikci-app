/// Düğüm rehberi modeli.
class KnotModel {
  // cleaned: model yapısı H11 JSON formatına göre yenilendi
  final String id;
  final String title;
  final String category;
  final List<String> steps;
  final int difficulty;
  final List<String> useCases;

  const KnotModel({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.useCases,
    required this.steps,
  });

  factory KnotModel.fromJson(Map<String, dynamic> json) => KnotModel(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    useCases:
        (json['use_cases'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const [],
    steps:
        (json['steps'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const [],
  );
}
