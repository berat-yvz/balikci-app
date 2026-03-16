/// Mera modeli — ARCHITECTURE.md `fishing_spots` tablosu referans.
class SpotModel {
  final String id;
  final String userId;
  final String name;
  final double lat;
  final double lng;
  final String? type; // kıyı | kayalık | iskele | tekne | göl | nehir
  final String privacyLevel; // public | friends | private | vip
  final String? description;
  final bool verified;
  final String? muhtarId;
  final DateTime createdAt;

  const SpotModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.lat,
    required this.lng,
    this.type,
    this.privacyLevel = 'public',
    this.description,
    this.verified = false,
    this.muhtarId,
    required this.createdAt,
  });

  factory SpotModel.fromJson(Map<String, dynamic> json) => SpotModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        type: json['type'] as String?,
        privacyLevel: json['privacy_level'] as String? ?? 'public',
        description: json['description'] as String?,
        verified: json['verified'] as bool? ?? false,
        muhtarId: json['muhtar_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'lat': lat,
        'lng': lng,
        'type': type,
        'privacy_level': privacyLevel,
        'description': description,
        'verified': verified,
        'muhtar_id': muhtarId,
        'created_at': createdAt.toIso8601String(),
      };
}
