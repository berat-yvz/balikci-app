/// Check-in modeli — ARCHITECTURE.md `checkins` tablosu referans.
class CheckinModel {
  final String id;
  final String userId;
  final String spotId;
  final String? crowdLevel; // yoğun | normal | az | boş
  final String? fishDensity; // yoğun | normal | az | yok
  final String? photoUrl;
  final bool exifVerified;
  final bool isActive;
  final DateTime createdAt;

  const CheckinModel({
    required this.id,
    required this.userId,
    required this.spotId,
    this.crowdLevel,
    this.fishDensity,
    this.photoUrl,
    this.exifVerified = false,
    this.isActive = true,
    required this.createdAt,
  });

  /// Rapor 2 saatten eski mi? (soluk gösterim için)
  bool get isStale =>
      DateTime.now().difference(createdAt).inHours >= 2;

  /// Rapor 6 saatten eski mi? (haritadan kaldır)
  bool get isExpired =>
      DateTime.now().difference(createdAt).inHours >= 6;

  factory CheckinModel.fromJson(Map<String, dynamic> json) => CheckinModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        spotId: json['spot_id'] as String,
        crowdLevel: json['crowd_level'] as String?,
        fishDensity: json['fish_density'] as String?,
        photoUrl: json['photo_url'] as String?,
        exifVerified: json['exif_verified'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'spot_id': spotId,
        'crowd_level': crowdLevel,
        'fish_density': fishDensity,
        'photo_url': photoUrl,
        'exif_verified': exifVerified,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}
