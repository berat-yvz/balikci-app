/// Kullanıcı modeli — ARCHITECTURE.md `users` tablosu referans.
class UserModel {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final String rank; // acemi | olta_kurdu | usta | deniz_reisi
  final int totalScore;
  final int sustainabilityScore;
  final String? fcmToken;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.rank = 'acemi',
    this.totalScore = 0,
    this.sustainabilityScore = 0,
    this.fcmToken,
    required this.createdAt,
  });

  /// RPC satırlarında `email` gelmeyebilir; otomatik `user_*` adını o zaman da göster.
  static String _resolveUsername(String? raw, String email, String userId) {
    final trimmed = raw?.trim() ?? '';
    final autoPattern = RegExp(r'^user_[0-9a-f]{6,}$', caseSensitive: false);
    if (trimmed.isNotEmpty && !autoPattern.hasMatch(trimmed)) {
      return trimmed;
    }
    final mail = email.trim();
    if (mail.isNotEmpty) {
      return mail.split('@').first;
    }
    if (trimmed.isNotEmpty) return trimmed;
    final compact = userId.replaceAll('-', '');
    final tail = compact.length >= 6
        ? compact.substring(compact.length - 6)
        : compact;
    return tail.isNotEmpty ? 'Balıkçı_$tail' : 'Balıkçı';
  }

  /// RPC / join sonucu tek satırda `email` yokken sosyal ve sıralama listeleri için.
  static String displayUsername({
    String? rawUsername,
    String email = '',
    required String userId,
  }) =>
      _resolveUsername(rawUsername, email, userId);

  /// JSON / PostgREST sayıları (int, double, büyük bigint string) için güvenli dönüşüm.
  static int coerceToInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final resolvedName = _resolveUsername(
      json['username'] as String?,
      json['email'] as String? ?? '',
      id,
    );
    final createdRaw = json['created_at'] as String?;
    return UserModel(
      id: id,
      email: json['email'] as String? ?? '',
      username: resolvedName.trim().isEmpty ? 'Balıkçı' : resolvedName,
      avatarUrl: json['avatar_url'] as String?,
      rank: json['rank'] as String? ?? 'acemi',
      totalScore: coerceToInt(json['total_score']),
      sustainabilityScore: coerceToInt(json['sustainability_score']),
      fcmToken: json['fcm_token'] as String?,
      createdAt: createdRaw != null
          ? DateTime.tryParse(createdRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'avatar_url': avatarUrl,
    'rank': rank,
    'total_score': totalScore,
    'sustainability_score': sustainabilityScore,
    'fcm_token': fcmToken,
    'created_at': createdAt.toIso8601String(),
  };
}
