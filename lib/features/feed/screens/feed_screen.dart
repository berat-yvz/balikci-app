import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/feed/screens/create_post_screen.dart';
import 'package:balikci_app/features/feed/screens/post_detail_screen.dart';
import 'package:balikci_app/features/feed/widgets/post_card.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Sosyal akış — herkese açık gönderiler; arkadaşlar için üst çubuktaki simge.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Sosyal 🎣',
          style: TextStyle(
            color: AppColors.foam,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline_rounded,
                color: AppColors.foam),
            iconSize: 22,
            tooltip: 'Arkadaşlar',
            onPressed: () => context.push(AppRoutes.socialHub),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.foam),
            iconSize: 28,
            tooltip: 'Gönderi Paylaş',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreatePostScreen(),
                fullscreenDialog: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: const _GlobalFeedList(),
    );
  }
}

class _GlobalFeedList extends ConsumerWidget {
  const _GlobalFeedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(globalFeedProvider);
    final notifier = ref.read(globalFeedProvider.notifier);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: notifier.refresh,
      child: feedAsync.when(
        loading: () => const _PostSkeletonList(),
        error: (_, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: _FeedErrorWidget(onRetry: notifier.refresh),
            ),
          ],
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: _EmptyGlobalWidget(
                    onShare: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreatePostScreen(),
                        fullscreenDialog: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification &&
                  n.metrics.extentAfter < 300) {
                notifier.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SliverList.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, i) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PostCard(
                          post: posts[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PostDetailScreen(post: posts[i]),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey.shade800,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Hata widget'ı ─────────────────────────────────────────────────────────────

class _FeedErrorWidget extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _FeedErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: AppColors.muted,
              ),
              const SizedBox(height: 16),
              const Text(
                'İnternet bağlantını kontrol et\nve sayfayı yenile 🎣',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foam,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.foam,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    '🔄 Tekrar Dene',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _PostSkeletonList extends StatelessWidget {
  const _PostSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: 3,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.shade800,
      ),
      itemBuilder: (_, _) => const _PostSkeleton(),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.muted.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.muted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.muted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: w * 0.85,
            color: AppColors.muted.withValues(alpha: 0.2),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 64,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Boş durum — genel akış ───────────────────────────────────────────────────

class _EmptyGlobalWidget extends StatelessWidget {
  final VoidCallback onShare;

  const _EmptyGlobalWidget({required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text(
            'Henüz gönderi yok',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.foam,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk paylaşan sen ol!',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.foam,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Paylaş',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
