/// Balık günlüğü modeli — ARCHITECTURE.md `fish_logs` tablosu referans.
/// MVP_PLAN.md M-05 FishLog sınıfından.
class FishLogModel {
  final String id;
  final String userId;
  final String? spotId;
  final String species;
  final double? weight;
  final double? length;
  final String? photoUrl;
  final Map<String, dynamic>? weatherSnapshot;
  final bool isPrivate;
  final bool released; // sürdürülebilirlik: balığı saldı
  final DateTime createdAt;

  const FishLogModel({
    required this.id,
    required this.userId,
    this.spotId,
    required this.species,
    this.weight,
    this.length,
    this.photoUrl,
    this.weatherSnapshot,
    this.isPrivate = false,
    this.released = false,
    required this.createdAt,
  });

  factory FishLogModel.fromJson(Map<String, dynamic> json) => FishLogModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        spotId: json['spot_id'] as String?,
        species: json['species'] as String,
        weight: (json['weight'] as num?)?.toDouble(),
        length: (json['length'] as num?)?.toDouble(),
        photoUrl: json['photo_url'] as String?,
        weatherSnapshot:
            json['weather_snapshot'] as Map<String, dynamic>?,
        isPrivate: json['is_private'] as bool? ?? false,
        released: json['released'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'spot_id': spotId,
        'species': species,
        'weight': weight,
        'length': length,
        'photo_url': photoUrl,
        'weather_snapshot': weatherSnapshot,
        'is_private': isPrivate,
        'released': released,
        'created_at': createdAt.toIso8601String(),
      };
}
