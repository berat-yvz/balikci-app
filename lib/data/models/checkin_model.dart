/// Check-in modeli — ARCHITECTURE.md `checkins` tablosu referans.
class CheckinModel {
  // cleaned: oy sayıları ve gizleme kuralı model seviyesine eklendi
  final String id;
  final String userId;
  final String spotId;
  final String? username;
  final String? crowdLevel; // yoğun | normal | az | boş
  final String? fishDensity; // yoğun | normal | az | yok
  final String? photoUrl;
  final bool exifVerified;
  final bool isHidden;
  final int trueVotes;
  final int falseVotes;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const CheckinModel({
    required this.id,
    required this.userId,
    required this.spotId,
    this.username,
    this.crowdLevel,
    this.fishDensity,
    this.photoUrl,
    this.exifVerified = false,
    this.isHidden = false,
    this.trueVotes = 0,
    this.falseVotes = 0,
    required this.createdAt,
    this.expiresAt,
  });

  /// Bildirim aktif mi? Gizlenmemiş ve süresi dolmamış olmalı.
  bool get isActive {
    if (isHidden) return false;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  /// Rapor 2 saatten eski mi? (soluk gösterim için)
  bool get isStale => DateTime.now().difference(createdAt).inHours >= 2;

  /// Rapor 6 saatten eski mi? (haritadan kaldır)
  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 6;

  factory CheckinModel.fromJson(Map<String, dynamic> json) => CheckinModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    spotId: json['spot_id'] as String,
    username: _parseUsername(json['users']),
    crowdLevel: json['crowd_level'] as String?,
    fishDensity: json['fish_density'] as String?,
    photoUrl: json['photo_url'] as String?,
    exifVerified: json['exif_verified'] as bool? ?? false,
    isHidden: json['is_hidden'] as bool? ?? false,
    trueVotes: (json['true_votes'] as num?)?.toInt() ?? 0,
    falseVotes: (json['false_votes'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'spot_id': spotId,
    'username': username,
    'crowd_level': crowdLevel,
    'fish_density': fishDensity,
    'photo_url': photoUrl,
    'exif_verified': exifVerified,
    'is_hidden': isHidden,
    'true_votes': trueVotes,
    'false_votes': falseVotes,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };

  static String? _parseUsername(dynamic usersField) {
    if (usersField is Map<String, dynamic>) {
      return usersField['username'] as String?;
    }
    if (usersField is List && usersField.isNotEmpty) {
      final first = usersField.first;
      if (first is Map<String, dynamic>) {
        return first['username'] as String?;
      }
    }
    return null;
  }
}
