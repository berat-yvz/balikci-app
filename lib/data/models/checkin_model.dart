import 'package:balikci_app/core/constants/app_constants.dart';

import 'package:balikci_app/data/models/user_model.dart';

/// Check-in modeli — ARCHITECTURE.md `checkins` tablosu referans.
class CheckinModel {
  // cleaned: oy sayıları ve gizleme kuralı model seviyesine eklendi
  final String id;
  final String userId;
  final String spotId;
  final String? username;
  final String? crowdLevel; // yoğun | normal | az | boş
  final String? fishDensity; // yoğun | normal | az | yok
  /// Seçilen balık türleri (örn. Levrek, Lüfer) — DB `fish_species text[]`.
  final List<String> fishSpecies;
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
    this.fishSpecies = const [],
    this.photoUrl,
    this.exifVerified = false,
    this.isHidden = false,
    this.trueVotes = 0,
    this.falseVotes = 0,
    required this.createdAt,
    this.expiresAt,
  });

  /// Oy tabanlı gizleme: AppConstants eşik değerlerini kullanır.
  bool get isSuppressedByVotes {
    final total = trueVotes + falseVotes;
    if (total < AppConstants.minVotesForHide) return false;
    return falseVotes / total >= AppConstants.voteThresholdPercent;
  }

  /// Bildirim aktif mi? Gizlenmemiş ve oy baskısı yok olmalı.
  ///
  /// - `expires_at` doluysa: sunucu süresi geçmemiş olmalı.
  /// - `expires_at` null ise (eski kayıtlar / tetik yok): [isExpired] ile aynı
  ///   mantık — yani son [AppConstants.checkinRemoveHours] saat içinde oluşturulmuş
  ///   sayılır; harita sorgularıyla uyumlu.
  bool get isActive {
    if (isHidden) return false;
    if (isSuppressedByVotes) return false;
    final now = DateTime.now();
    final exp = expiresAt;
    if (exp != null) {
      return exp.isAfter(now);
    }
    return !isExpired;
  }

  /// Rapor 2 saatten eski mi? (soluk gösterim için)
  bool get isStale => DateTime.now().difference(createdAt).inHours >= 2;

  /// Rapor 6 saatten eski mi? (haritadan kaldır)
  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 6;

  factory CheckinModel.fromJson(Map<String, dynamic> json) {
    final uid = json['user_id'] as String;
    return CheckinModel(
      id: json['id'] as String,
      userId: uid,
      spotId: json['spot_id'] as String,
      username: _displayUsername(json['users'], uid),
      crowdLevel: json['crowd_level'] as String?,
      fishDensity: json['fish_density'] as String?,
      fishSpecies: _parseStringList(json['fish_species']),
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
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'spot_id': spotId,
    'username': username,
    'crowd_level': crowdLevel,
    'fish_density': fishDensity,
    if (fishSpecies.isNotEmpty) 'fish_species': fishSpecies,
    'photo_url': photoUrl,
    'exif_verified': exifVerified,
    'is_hidden': isHidden,
    'true_votes': trueVotes,
    'false_votes': falseVotes,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _displayUsername(dynamic usersField, String userId) {
    var raw = '';
    var email = '';
    if (usersField is Map<String, dynamic>) {
      raw = usersField['username'] as String? ?? '';
      email = usersField['email'] as String? ?? '';
    } else if (usersField is List && usersField.isNotEmpty) {
      final first = usersField.first;
      if (first is Map<String, dynamic>) {
        raw = first['username'] as String? ?? '';
        email = first['email'] as String? ?? '';
      }
    }
    return UserModel.displayUsername(
      rawUsername: raw.isEmpty ? null : raw,
      email: email,
      userId: userId,
    );
  }
}
