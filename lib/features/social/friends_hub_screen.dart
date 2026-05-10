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
        body: TabBarView(
          children: [
            const _KeepAliveFriendsListTab(),
            const CommunityDiscoverScreen(showShortcutRow: false),
          ],
        ),
      ),
    );
  }
}

/// Sekme değişince [FriendsListScreen] dispose olmasın — arkadaş provider yükleme yarışı ve
/// gereksiz yeniden isteklerin önüne geçer.
class _KeepAliveFriendsListTab extends StatefulWidget {
  const _KeepAliveFriendsListTab();

  @override
  State<_KeepAliveFriendsListTab> createState() =>
      _KeepAliveFriendsListTabState();
}

class _KeepAliveFriendsListTabState extends State<_KeepAliveFriendsListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const FriendsListScreen(embedded: true);
  }
}
