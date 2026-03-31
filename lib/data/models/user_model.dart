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

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    avatarUrl: json['avatar_url'] as String?,
    rank: json['rank'] as String? ?? 'acemi',
    totalScore: json['total_score'] as int? ?? 0,
    sustainabilityScore: json['sustainability_score'] as int? ?? 0,
    fcmToken: json['fcm_token'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

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
