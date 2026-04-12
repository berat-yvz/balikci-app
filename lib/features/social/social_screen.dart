import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/rank/leaderboard_screen.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

/// Topluluk — arkadaşlık istekleri ve keşif.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentUserProvider);
    final searchAsync = ref.watch(userSearchByUsernameProvider(_searchQuery));
    final discoverAsync = ref.watch(allRegisteredAnglersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Topluluk'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: ColoredBox(
              color: AppColors.navy,
              child: TabBar(
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Arkadaşlar'),
                  Tab(text: 'Sıralama'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            CustomScrollView(
              slivers: [
                if (current != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ShortcutCard(
                              icon: Icons.people_outline,
                              label: 'Arkadaşlarım',
                              onTap: () =>
                                  context.push(AppRoutes.socialFriends),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ShortcutCard(
                              icon: Icons.mail_outline,
                              label: 'İstekler',
                              onTap: () =>
                                  context.push(AppRoutes.socialRequests),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Balıkçı ara (kullanıcı adı)',
                        hintStyle: TextStyle(color: AppColors.muted),
                        prefixIcon:
                            const Icon(Icons.search, color: AppColors.muted),
                        filled: true,
                        fillColor: const Color(0xFF132236),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.muted.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.muted.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.length >= 2)
                  searchAsync.when(
                    data: (users) {
                      if (users.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Sonuç bulunamadı.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ),
                        );
                      }
                      return SliverMainAxisGroup(
                        slivers: [
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                'Arama sonuçları',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          SliverList.separated(
                            itemCount: users.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final u = users[i];
                              return _DiscoverUserTile(user: u);
                            },
                          ),
                        ],
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Arama başarısız: $e',
                          style: const TextStyle(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Kayıtlı balıkçılar — profil açıp arkadaşlık isteği gönderebilirsin',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  discoverAsync.when(
                    data: (users) {
                      final selfId = current?.id;
                      final list = selfId == null
                          ? users
                          : users.where((u) => u.id != selfId).toList();
                      if (list.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Liste boş.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ),
                        );
                      }
                      return SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _DiscoverUserTile(user: list[i]),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Liste yüklenemedi: $e',
                          style: const TextStyle(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
            const LeaderboardScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF132236),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverUserTile extends ConsumerWidget {
  final UserModel user;

  const _DiscoverUserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = user.avatarUrl;
    final edgeAsync = ref.watch(socialEdgeProvider(user.id));

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        backgroundImage: avatar != null && avatar.isNotEmpty
            ? NetworkImage(_publicAvatarUrl(avatar))
            : null,
        child: avatar == null || avatar.isEmpty
            ? Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${user.totalScore} puan',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      trailing: edgeAsync.when(
        data: (edge) {
          switch (edge.kind) {
            case SocialEdgeKind.self:
              return const SizedBox.shrink();
            case SocialEdgeKind.mutualFriend:
              return Text(
                'Arkadaş',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              );
            case SocialEdgeKind.outgoingPending:
              return TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(friendRequestRepositoryProvider)
                        .cancelOutgoing(user.id);
                    ref.invalidate(socialEdgeProvider(user.id));
                  } catch (_) {}
                },
                child: const Text('İptal', style: TextStyle(fontSize: 12)),
              );
            case SocialEdgeKind.incomingPending:
              return FilledButton(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: edge.incomingRequestId == null
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(friendRequestRepositoryProvider)
                              .acceptRequest(edge.incomingRequestId!);
                          ref.invalidate(socialEdgeProvider(user.id));
                          ref.invalidate(mutualFriendsProvider);
                          ref.invalidate(incomingRequestsWithProfilesProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                child: const Text('Kabul', style: TextStyle(fontSize: 12)),
              );
            case SocialEdgeKind.stranger:
              return FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(friendRequestRepositoryProvider)
                        .sendRequest(user.id);
                    ref.invalidate(socialEdgeProvider(user.id));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İstek gönderildi')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                },
                child:
                    const Text('İstek', style: TextStyle(fontSize: 12)),
              );
          }
        },
        loading: () => const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (Object? _, StackTrace? _) => const SizedBox.shrink(),
      ),
      onTap: () => context.push('${AppRoutes.profile}/${user.id}'),
    );
  }
}

String _publicAvatarUrl(String avatarUrlOrPath) {
  if (avatarUrlOrPath.startsWith('http')) return avatarUrlOrPath;
  final base = dotenv.env['SUPABASE_URL'] ?? '';
  if (base.isEmpty) return avatarUrlOrPath;
  final bucket = avatarStorageBucket();
  return '$base/storage/v1/object/public/$bucket/$avatarUrlOrPath';
}
