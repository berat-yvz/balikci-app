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
  final bool isActive;
  final int trueVotes;
  final int falseVotes;
  final DateTime createdAt;

  const CheckinModel({
    required this.id,
    required this.userId,
    required this.spotId,
    this.username,
    this.crowdLevel,
    this.fishDensity,
    this.photoUrl,
    this.exifVerified = false,
    this.isActive = true,
    this.trueVotes = 0,
    this.falseVotes = 0,
    required this.createdAt,
  });

  /// Rapor 2 saatten eski mi? (soluk gösterim için)
  bool get isStale => DateTime.now().difference(createdAt).inHours >= 2;

  /// Rapor 6 saatten eski mi? (haritadan kaldır)
  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 6;

  /// En az 3 yanlış oy ve %70 üstü yanlış oranında rapor gizlenir.
  bool get isHidden {
    final total = trueVotes + falseVotes;
    if (falseVotes < 3 || total == 0) return false;
    return (falseVotes / total) > 0.70;
  }

  factory CheckinModel.fromJson(Map<String, dynamic> json) => CheckinModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    spotId: json['spot_id'] as String,
    username: _parseUsername(json['users']),
    crowdLevel: json['crowd_level'] as String?,
    fishDensity: json['fish_density'] as String?,
    photoUrl: json['photo_url'] as String?,
    exifVerified: json['exif_verified'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    trueVotes: (json['true_votes'] as num?)?.toInt() ?? 0,
    falseVotes: (json['false_votes'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
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
    'is_active': isActive,
    'true_votes': trueVotes,
    'false_votes': falseVotes,
    'created_at': createdAt.toIso8601String(),
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
