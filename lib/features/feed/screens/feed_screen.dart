import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/screens/create_post_screen.dart';
import 'package:balikci_app/features/feed/screens/post_detail_screen.dart';
import 'package:balikci_app/features/feed/widgets/post_card.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';
import 'package:balikci_app/shared/widgets/empty_state_widget.dart';
import 'package:balikci_app/shared/widgets/skeleton_widget.dart';

/// Sosyal akış — Arkadaşlar ve Türkiye sekmeleri.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Akış 🎣'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 28),
              tooltip: 'Gönderi Oluştur',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreatePostScreen(),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '👥 Arkadaşlar'),
              Tab(text: '🇹🇷 Türkiye'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.foam,
            unselectedLabelColor: AppColors.muted,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsFeedList(),
            _GlobalFeedList(),
          ],
        ),
      ),
    );
  }
}

// ── Arkadaşlar sekmesi ───────────────────────────────────────────────────────

class _FriendsFeedList extends ConsumerStatefulWidget {
  const _FriendsFeedList();

  @override
  ConsumerState<_FriendsFeedList> createState() => _FriendsFeedListState();
}

class _FriendsFeedListState extends ConsumerState<_FriendsFeedList> {
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(friendsFeedProvider.notifier);
    final posts = ref.read(friendsFeedProvider).valueOrNull ?? [];
    if (posts.isEmpty) return;
    if (_scroll.position.extentAfter < 300 && !notifier.isLoadingMore) {
      notifier.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(friendsFeedProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(friendsFeedProvider.notifier).refresh(),
      child: feedAsync.when(
        loading: () => _SkeletonFeed(),
        error: (e, _) => _FeedError(
          onRetry: () => ref.read(friendsFeedProvider.notifier).refresh(),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return EmptyStateWidget(
              title: 'Henüz arkadaşının gönderisi yok',
              subtitle: 'İnsanları takip etmeye başla!',
              icon: Icons.people_outline_rounded,
              buttonLabel: 'Kişileri Keşfet',
              onButtonPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.social),
            );
          }
          return ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: posts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return _LoadMoreIndicator(
                  loading: ref.watch(friendsFeedProvider.notifier).isLoadingMore,
                );
              }
              return PostCard(
                post: posts[index],
                onTap: () => _openDetail(context, posts[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
    );
  }
}

// ── Türkiye sekmesi ──────────────────────────────────────────────────────────

class _GlobalFeedList extends ConsumerStatefulWidget {
  const _GlobalFeedList();

  @override
  ConsumerState<_GlobalFeedList> createState() => _GlobalFeedListState();
}

class _GlobalFeedListState extends ConsumerState<_GlobalFeedList> {
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(globalFeedProvider.notifier);
    final posts = ref.read(globalFeedProvider).valueOrNull ?? [];
    if (posts.isEmpty) return;
    if (_scroll.position.extentAfter < 300 && !notifier.isLoadingMore) {
      notifier.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(globalFeedProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(globalFeedProvider.notifier).refresh(),
      child: feedAsync.when(
        loading: () => _SkeletonFeed(),
        error: (e, _) => _FeedError(
          onRetry: () => ref.read(globalFeedProvider.notifier).refresh(),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyStateWidget(
              title: 'Henüz hiç gönderi yok',
              subtitle: 'İlk paylaşan sen ol!',
              icon: Icons.public_rounded,
            );
          }
          return ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: posts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                return _LoadMoreIndicator(
                  loading: ref.watch(globalFeedProvider.notifier).isLoadingMore,
                );
              }
              return PostCard(
                post: posts[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailScreen(post: posts[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────────────────

class _SkeletonFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const SkeletonListTile(hasLeadingCircle: true),
    );
  }
}

class _FeedError extends StatelessWidget {
  final VoidCallback onRetry;

  const _FeedError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text(
            'Bağlantı hatası',
            style: TextStyle(fontSize: 16, color: AppColors.foam),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yenile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  final bool loading;

  const _LoadMoreIndicator({required this.loading});

  @override
  Widget build(BuildContext context) {
    if (!loading) return const SizedBox(height: 24);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
