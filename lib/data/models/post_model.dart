import 'package:balikci_app/data/models/user_model.dart';

/// Mera gizlilik seviyeleri — fishing_spots.privacy_level ile eşdeğer semantik.
enum SpotPrivacyLevel {
  public,
  friends,
  private,
  vip;

  static SpotPrivacyLevel fromString(String? value) {
    switch (value) {
      case 'friends':
        return SpotPrivacyLevel.friends;
      case 'private':
        return SpotPrivacyLevel.private;
      case 'vip':
        return SpotPrivacyLevel.vip;
      default:
        return SpotPrivacyLevel.public;
    }
  }

  String toJson() => name;
}

/// Sosyal akış gönderisi — Supabase [posts] tablosunun istemci modeli.
///
/// [spotName], [authorUsername], [authorAvatarUrl], [authorRank] posts
/// tablosunda saklanmaz; sorgularda `author:users!posts_user_id_fkey(...)` ve
/// `spot:fishing_spots(name)` join'leri ile doldurulur.
class PostModel {
  final String id;
  final String userId;
  final String photoUrl;
  final String? caption;
  final List<String>? fishSpecies;

  final String? spotId;
  final SpotPrivacyLevel spotPrivacySnapshot;
  final String? spotDistrict;

  /// fishing_spots.name — join ile doldurulur, tabloda saklanmaz.
  final String? spotName;

  /// Gönderi sahibinin kullanıcı adı — users join'inden doldurulur.
  final String? authorUsername;

  /// Gönderi sahibinin avatar URL'si — users join'inden doldurulur.
  final String? authorAvatarUrl;

  /// Gönderi sahibinin rütbesi — users join'inden doldurulur.
  final String? authorRank;

  final int likesCount;
  final int commentsCount;
  final bool isDeleted;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.userId,
    required this.photoUrl,
    this.caption,
    this.fishSpecies,
    this.spotId,
    this.spotPrivacySnapshot = SpotPrivacyLevel.public,
    this.spotDistrict,
    this.spotName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorRank,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isDeleted = false,
    required this.createdAt,
  });

  /// Gizlilik seviyesine göre maskelenmiş mera adı.
  ///
  /// - public / friends → gerçek mera adı (bilinmiyorsa ilçe adı)
  /// - private          → '📍 {ilçe}' veya '📍 Bölge'
  /// - vip              → '🔒 VIP Mera'
  String get displaySpotName {
    switch (spotPrivacySnapshot) {
      case SpotPrivacyLevel.public:
      case SpotPrivacyLevel.friends:
        return spotName ?? spotDistrict ?? '';
      case SpotPrivacyLevel.private:
        return '📍 ${spotDistrict ?? "Bölge"}';
      case SpotPrivacyLevel.vip:
        return '🔒 VIP Mera';
    }
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // fish_species: Supabase TEXT[] → List<String>
    List<String>? parsedSpecies;
    final rawSpecies = json['fish_species'];
    if (rawSpecies is List) {
      parsedSpecies = rawSpecies.map((e) => e.toString()).toList();
    }

    final spotPrivacySnapshot =
        SpotPrivacyLevel.fromString(json['spot_privacy_snapshot'] as String?);

    // spot join: PostgREST nested object veya null
    String? parsedSpotName;
    final rawSpot = json['spot'];
    if (rawSpot is Map<String, dynamic>) {
      parsedSpotName = rawSpot['name'] as String?;
    }

    String? parsedDistrict = json['spot_district'] as String?;
    if (spotPrivacySnapshot == SpotPrivacyLevel.vip) {
      parsedSpotName = null;
      parsedDistrict = null;
    }

    // author join: author:users!posts_user_id_fkey(...)
    String? rawAuthorUsername;
    String? parsedAuthorAvatarUrl;
    String? parsedAuthorRank;
    var parsedAuthorEmail = '';
    final rawAuthor = json['author'];
    if (rawAuthor is Map<String, dynamic>) {
      rawAuthorUsername = rawAuthor['username'] as String?;
      parsedAuthorAvatarUrl = rawAuthor['avatar_url'] as String?;
      parsedAuthorRank = rawAuthor['rank'] as String?;
      parsedAuthorEmail = rawAuthor['email'] as String? ?? '';
    }

    final uid = json['user_id'] as String;
    final resolvedAuthorUsername = UserModel.displayUsername(
      rawUsername: rawAuthorUsername,
      email: parsedAuthorEmail,
      userId: uid,
    );

    return PostModel(
      id: json['id'] as String,
      userId: uid,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      fishSpecies: parsedSpecies,
      spotId: json['spot_id'] as String?,
      spotPrivacySnapshot: spotPrivacySnapshot,
      spotDistrict: parsedDistrict,
      spotName: parsedSpotName,
      authorUsername: resolvedAuthorUsername,
      authorAvatarUrl: parsedAuthorAvatarUrl,
      authorRank: parsedAuthorRank,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'photo_url': photoUrl,
        'caption': caption,
        'fish_species': fishSpecies,
        'spot_id': spotId,
        'spot_privacy_snapshot': spotPrivacySnapshot.toJson(),
        'spot_district': spotDistrict,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
      };

  PostModel copyWith({
    String? id,
    String? userId,
    String? photoUrl,
    String? caption,
    List<String>? fishSpecies,
    String? spotId,
    SpotPrivacyLevel? spotPrivacySnapshot,
    String? spotDistrict,
    String? spotName,
    String? authorUsername,
    String? authorAvatarUrl,
    String? authorRank,
    int? likesCount,
    int? commentsCount,
    bool? isDeleted,
    DateTime? createdAt,
  }) =>
      PostModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        photoUrl: photoUrl ?? this.photoUrl,
        caption: caption ?? this.caption,
        fishSpecies: fishSpecies ?? this.fishSpecies,
        spotId: spotId ?? this.spotId,
        spotPrivacySnapshot: spotPrivacySnapshot ?? this.spotPrivacySnapshot,
        spotDistrict: spotDistrict ?? this.spotDistrict,
        spotName: spotName ?? this.spotName,
        authorUsername: authorUsername ?? this.authorUsername,
        authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
        authorRank: authorRank ?? this.authorRank,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Gönderi yorumu — Supabase [post_comments] tablosunun istemci modeli.
///
/// [username] ve [avatarUrl] tabloda saklanmaz; sorgu sırasında
/// `users(username, avatar_url)` join'i ile doldurulur.
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // users join: PostgREST nested object
    String? rawUsername;
    String? parsedAvatarUrl;
    var parsedEmail = '';
    final rawUser = json['user'];
    if (rawUser is Map<String, dynamic>) {
      rawUsername = rawUser['username'] as String?;
      parsedAvatarUrl = rawUser['avatar_url'] as String?;
      parsedEmail = rawUser['email'] as String? ?? '';
    }

    final uid = json['user_id'] as String;

    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: uid,
      username: UserModel.displayUsername(
        rawUsername: rawUsername,
        email: parsedEmail,
        userId: uid,
      ),
      avatarUrl: parsedAvatarUrl,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}
