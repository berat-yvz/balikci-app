import 'package:flutter_test/flutter_test.dart';
import 'package:balikci_app/data/models/post_model.dart';

/// Temel bir PostModel JSON verisi döner.
Map<String, dynamic> _baseJson({
  String id = 'post-1',
  String userId = 'user-1',
  String photoUrl = 'https://example.com/photo.jpg',
  String? caption,
  List<dynamic>? fishSpecies,
  String? spotId,
  String spotPrivacySnapshot = 'public',
  String? spotDistrict,
  int likesCount = 0,
  int commentsCount = 0,
  Map<String, dynamic>? author,
  Map<String, dynamic>? spot,
  String createdAt = '2026-04-15T10:00:00.000Z',
}) {
  return {
    'id': id,
    'user_id': userId,
    'photo_url': photoUrl,
    'caption': caption,
    'fish_species': fishSpecies,
    'spot_id': spotId,
    'spot_privacy_snapshot': spotPrivacySnapshot,
    'spot_district': spotDistrict,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'is_deleted': false,
    'created_at': createdAt,
    'author': author,
    'spot': spot,
  };
}

void main() {
  group('PostModel.fromJson', () {
    test('public spot — tam veriyle doğru parse edilir', () {
      final json = _baseJson(
        caption: 'Güzel bir av!',
        fishSpecies: ['Lüfer', 'Çipura'],
        spotPrivacySnapshot: 'public',
        likesCount: 3,
        commentsCount: 1,
        author: {
          'username': 'balikci_ahmet',
          'avatar_url': null,
          'rank': 'olta_kurdu',
        },
        spot: {'name': 'Haliç Köprüsü'},
      );
      final post = PostModel.fromJson(json);

      expect(post.id, 'post-1');
      expect(post.userId, 'user-1');
      expect(post.caption, 'Güzel bir av!');
      expect(post.fishSpecies, ['Lüfer', 'Çipura']);
      expect(post.spotPrivacySnapshot, SpotPrivacyLevel.public);
      expect(post.likesCount, 3);
      expect(post.commentsCount, 1);
      expect(post.authorUsername, 'balikci_ahmet');
      expect(post.authorRank, 'olta_kurdu');
      expect(post.spotName, 'Haliç Köprüsü');
    });

    test('fishSpecies null → null olarak kalır', () {
      final post = PostModel.fromJson(_baseJson());
      expect(post.fishSpecies, isNull);
    });

    test('fishSpecies boş liste → boş liste', () {
      final post = PostModel.fromJson(_baseJson(fishSpecies: []));
      expect(post.fishSpecies, isEmpty);
    });

    test('author join yoksa authorUsername null olur', () {
      final post = PostModel.fromJson(_baseJson());
      expect(post.authorUsername, isNull);
    });

    test('private spot — displaySpotName "📍" ile başlar', () {
      final post = PostModel.fromJson(
        _baseJson(
          spotPrivacySnapshot: 'private',
          spotDistrict: 'Beşiktaş',
        ),
      );
      expect(post.displaySpotName, startsWith('📍'));
      expect(post.displaySpotName, contains('Beşiktaş'));
    });

    test('private spot, spotDistrict yok → "📍 Bölge"', () {
      final post = PostModel.fromJson(
        _baseJson(spotPrivacySnapshot: 'private'),
      );
      expect(post.displaySpotName, '📍 Bölge');
    });

    test('vip spot — displaySpotName "🔒 VIP Mera"', () {
      final post = PostModel.fromJson(
        _baseJson(spotPrivacySnapshot: 'vip'),
      );
      expect(post.displaySpotName, '🔒 VIP Mera');
    });

    test('friends spot — displaySpotName gerçek adı verir', () {
      final post = PostModel.fromJson(
        _baseJson(
          spotPrivacySnapshot: 'friends',
          spot: {'name': 'Gizli Mera'},
        ),
      );
      expect(post.displaySpotName, 'Gizli Mera');
    });

    test('toJson → fromJson round-trip tutarlılığı', () {
      final original = PostModel(
        id: 'post-rt',
        userId: 'user-rt',
        photoUrl: 'https://example.com/rt.jpg',
        caption: 'Roundtrip testi',
        fishSpecies: ['Levrek'],
        spotId: 'spot-1',
        spotPrivacySnapshot: SpotPrivacyLevel.friends,
        spotDistrict: 'Sarıyer',
        likesCount: 5,
        commentsCount: 2,
        createdAt: DateTime.utc(2026, 3, 10, 8, 30),
      );

      final json = original.toJson();
      final restored = PostModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.caption, original.caption);
      expect(restored.fishSpecies, original.fishSpecies);
      expect(restored.spotPrivacySnapshot, original.spotPrivacySnapshot);
      expect(restored.likesCount, original.likesCount);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('SpotPrivacyLevel.fromString', () {
    test('null → public', () {
      expect(SpotPrivacyLevel.fromString(null), SpotPrivacyLevel.public);
    });

    test('"friends" → friends', () {
      expect(SpotPrivacyLevel.fromString('friends'), SpotPrivacyLevel.friends);
    });

    test('"private" → private', () {
      expect(SpotPrivacyLevel.fromString('private'), SpotPrivacyLevel.private);
    });

    test('"vip" → vip', () {
      expect(SpotPrivacyLevel.fromString('vip'), SpotPrivacyLevel.vip);
    });

    test('bilinmeyen değer → public', () {
      expect(SpotPrivacyLevel.fromString('unknown'), SpotPrivacyLevel.public);
    });
  });
}
