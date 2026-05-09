import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balikci_app/features/social/friends_hub_screen.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FriendsHubScreen — Arkadaşlar başlığı ve Listem sekmesi',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          mutualFriendsProvider.overrideWith((ref) async => const []),
          allRegisteredAnglersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: FriendsHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arkadaşlar'), findsOneWidget);
    expect(find.text('Listem'), findsOneWidget);
    expect(find.text('Keşfet'), findsOneWidget);
  });
}
