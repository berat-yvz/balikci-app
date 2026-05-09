import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/social/community_discover_screen.dart';
import 'package:balikci_app/features/social/friends_list_screen.dart';

/// Arkadaş listesi + balıkçı keşfi — akış üzerindeki küçük girişten açılır.
class FriendsHubScreen extends StatelessWidget {
  const FriendsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Arkadaşlar'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: 'Listem'),
              Tab(text: 'Keşfet'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsListScreen(embedded: true),
            CommunityDiscoverScreen(showShortcutRow: false),
          ],
        ),
      ),
    );
  }
}
