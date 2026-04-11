import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balikci_app/features/social/social_screen.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SocialScreen — Topluluk başlığı görünür', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          leaderboardProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: SocialScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Topluluk'), findsOneWidget);
  });
}
