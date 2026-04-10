/// Takım önerisi — bir av senaryosu için gerekli malzemeleri listeler.
class TackleModel {
  final String id;
  final String title;
  final List<String> targetSpecies;
  final String season;
  final String technique;
  final int difficulty;
  final List<TackleItem> items;

  const TackleModel({
    required this.id,
    required this.title,
    required this.targetSpecies,
    required this.season,
    required this.technique,
    required this.difficulty,
    required this.items,
  });

  factory TackleModel.fromJson(Map<String, dynamic> json) => TackleModel(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    targetSpecies:
        (json['target_species'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const [],
    season: json['season'] as String? ?? '',
    technique: json['technique'] as String? ?? '',
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    items:
        (json['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(TackleItem.fromJson)
            .toList(growable: false) ??
        const [],
  );
}

class TackleItem {
  final String name;
  final String detail;
  final String tip;

  const TackleItem({
    required this.name,
    required this.detail,
    required this.tip,
  });

  factory TackleItem.fromJson(Map<String, dynamic> json) => TackleItem(
    name: json['name'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    tip: json['tip'] as String? ?? '',
  );
}
