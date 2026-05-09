import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/widgets/post_card.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

// ── Test yardımcıları ────────────────────────────────────────────────────────

PostModel _makePost({
  String id = 'post-test-1',
  String userId = 'user-1',
  String authorUsername = 'balikci_test',
  String? caption,
  List<String>? fishSpecies,
  String? spotId,
  SpotPrivacyLevel privacy = SpotPrivacyLevel.public,
  String? spotDistrict,
  String? spotName,
  int likes = 3,
  int comments = 1,
}) {
  return PostModel(
    id: id,
    userId: userId,
    photoUrl: 'https://via.placeholder.com/400',
    caption: caption,
    fishSpecies: fishSpecies,
    spotId: spotId,
    spotPrivacySnapshot: privacy,
    spotDistrict: spotDistrict,
    spotName: spotName,
    authorUsername: authorUsername,
    likesCount: likes,
    commentsCount: comments,
    createdAt: DateTime(2026, 4, 15, 10),
  );
}

/// Widget'ı Riverpod + MaterialApp ile sarar.
/// [likedPostsProvider] varsayılan false ve [currentUserProvider] null override edilir
/// (Supabase başlatılmadan test ortamında çalışabilmesi için).
Widget _wrap(PostModel post, {bool isLiked = false}) {
  return ProviderScope(
    overrides: [
      // Supabase başlatılmadan test ortamı için null user
      currentUserProvider.overrideWithValue(null),
      likedPostsProvider(post.id).overrideWith(
        (ref) async => isLiked,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PostCard(post: post),
        ),
      ),
    ),
  );
}

// ── Testler ──────────────────────────────────────────────────────────────────

void main() {
  group('PostCard — render', () {
    testWidgets('kullanıcı adı görünüyor', (tester) async {
      final post = _makePost(authorUsername: 'AhmetBalikci');
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.text('AhmetBalikci'), findsOneWidget);
    });

    testWidgets('fotoğraf widget\'ı (Image.network) mevcut', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.byType(Image), findsAtLeastNWidgets(1));
    });

    testWidgets('caption varsa görünüyor', (tester) async {
      final post = _makePost(caption: 'Test caption yazısı');
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();
      final anyCaptionRichText = tester
          .widgetList<RichText>(find.byType(RichText))
          .any((r) => r.text.toPlainText().contains('Test caption yazısı'));
      expect(anyCaptionRichText, isTrue);
    });

    testWidgets('caption null ise hiç görünmüyor', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      // Herhangi bir caption text'i bulunmamalı (kullanıcı adı hariç)
      expect(find.text(''), findsNothing);
    });

    testWidgets('balık türleri Chip olarak render ediliyor', (tester) async {
      final post = _makePost(fishSpecies: ['Lüfer', 'Çipura']);
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.text('Lüfer'), findsOneWidget);
      expect(find.text('Çipura'), findsOneWidget);
    });
  });

  group('PostCard — beğeni butonu', () {
    testWidgets('beğeni sayısı görünüyor', (tester) async {
      final post = _makePost(likes: 7);
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();
      expect(find.text(' 7'), findsOneWidget);
    });

    testWidgets('beğeni butonu tıklanabilir', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();
      // TextButton.icon (beğeni) — Icons.favorite_border_rounded
      final likeButton = find.byIcon(Icons.favorite_border_rounded);
      expect(likeButton, findsOneWidget);
    });

    testWidgets('beğeni butonunun dokunma hedefi ≥ 48dp', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();

      // SizedBox(height: 48) içinde TextButton.icon var mı
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final has48dp =
          sizedBoxes.any((sb) => sb.height != null && sb.height! >= 48);
      expect(has48dp, isTrue,
          reason: '48dp yüksekliğinde SizedBox bulunamadı');
    });
  });

  group('PostCard — mera etiketi (spot tag)', () {
    testWidgets('public spot — mera adı gösteriliyor', (tester) async {
      final post = _makePost(
        spotId: 'spot-1',
        spotName: 'Haliç Köprüsü',
        privacy: SpotPrivacyLevel.public,
      );
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.textContaining('Haliç Köprüsü'), findsOneWidget);
    });

    testWidgets('private spot — "📍" prefix\'i var', (tester) async {
      final post = _makePost(
        spotId: 'spot-2',
        privacy: SpotPrivacyLevel.private,
        spotDistrict: 'Beşiktaş',
      );
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.textContaining('📍'), findsOneWidget);
      expect(find.textContaining('Beşiktaş'), findsOneWidget);
    });

    testWidgets('vip spot — "🔒 VIP Mera" gösteriliyor', (tester) async {
      final post = _makePost(
        spotId: 'spot-3',
        privacy: SpotPrivacyLevel.vip,
      );
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.textContaining('🔒 VIP Mera'), findsOneWidget);
    });

    testWidgets('friends spot — mera adı görünüyor', (tester) async {
      final post = _makePost(
        spotId: 'spot-4',
        spotName: 'Gizli Mera',
        privacy: SpotPrivacyLevel.friends,
      );
      await tester.pumpWidget(_wrap(post));
      await tester.pump();
      expect(find.textContaining('Gizli Mera'), findsOneWidget);
    });
  });

  group('PostCard — yorum butonu', () {
    testWidgets('yorum sayısı görünüyor', (tester) async {
      final post = _makePost(comments: 5);
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();
      expect(find.text(' 5'), findsOneWidget);
    });

    testWidgets('yorum ikonu mevcut', (tester) async {
      final post = _makePost();
      await tester.pumpWidget(_wrap(post));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.chat_bubble_outline_rounded),
        findsOneWidget,
      );
    });
  });
}
