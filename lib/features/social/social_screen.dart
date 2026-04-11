import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';

/// Takip ve keşif — alt sekmeden erişilir; günlük yalnızca profilden açılır.
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
    final discoverAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Topluluk')),
      body: CustomScrollView(
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
                        label: 'Takip ettiklerim',
                        onTap: () => context.push(
                          '${AppRoutes.profile}/${current.id}/following',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ShortcutCard(
                        icon: Icons.group_outlined,
                        label: 'Takipçilerim',
                        onTap: () => context.push(
                          '${AppRoutes.profile}/${current.id}/followers',
                        ),
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
                    borderSide: const BorderSide(color: AppColors.primary),
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
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final u = users[i];
                        return _UserTile(
                          user: u,
                          onTap: () =>
                              context.push('${AppRoutes.profile}/${u.id}'),
                        );
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
                  'Öne çıkan balıkçılar — profil açıp takip edebilirsin',
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
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return _UserTile(
                      user: u,
                      onTap: () =>
                          context.push('${AppRoutes.profile}/${u.id}'),
                    );
                  },
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

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl;
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
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
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
