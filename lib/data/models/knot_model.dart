/// Düğüm modeli — Supabase `knots` tablosu.
class KnotModel {
  final String id;
  final String name;
  final String type;
  final String description;
  final List<String> steps;
  final int difficulty; // 1-5
  final String? imageUrl;

  const KnotModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.steps,
    required this.difficulty,
    this.imageUrl,
  });

  factory KnotModel.fromJson(Map<String, dynamic> json) => KnotModel(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    description: json['description'] as String? ?? '',
    steps:
        (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
  );
}
