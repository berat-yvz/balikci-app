import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/utils/time_utils.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

/// Sosyal akış gönderi kartı — border radius 0, Facebook tarzı.
///
/// Ana bölümler: yazar başlığı → fotoğraf → mera etiketi →
/// balık türleri → caption → aksiyon satırı.
class PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(currentUserProvider)?.id;
    final isOwner = myUid != null && myUid == post.userId;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.muted.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Üst başlık ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                _AuthorAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  username: post.authorUsername ?? 'Balıkçı',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorUsername ?? 'Balıkçı',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foam,
                        ),
                      ),
                      if (post.authorRank != null)
                        RankBadge(
                          rank: post.authorRank!,
                          size: RankBadgeSize.small,
                        ),
                    ],
                  ),
                ),
                Text(
                  timeAgo(post.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 4),
                  _PostMenu(postId: post.id),
                ],
              ],
            ),
          ),

          // ── Fotoğraf ───────────────────────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              height: screenWidth * 0.75,
              child: Image.network(
                post.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.muted.withValues(alpha: 0.15),
                  child: const Center(
                    child: Text(
                      '🐟 Fotoğraf yüklenemedi',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.muted.withValues(alpha: 0.15),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Alt bölüm ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mera
                if (post.spotId != null || post.spotDistrict != null) ...[
                  _SpotChip(post: post),
                  const SizedBox(height: 8),
                ],

                // Balık türleri
                if (post.fishSpecies != null &&
                    post.fishSpecies!.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: post.fishSpecies!
                        .map(
                          (s) => Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.foam,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Caption
                if (post.caption != null && post.caption!.isNotEmpty) ...[
                  Text(
                    post.caption!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.foam,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],

                // Aksiyon satırı
                _ActionRow(post: post, onCommentTap: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartın alt bölümü — PostDetailScreen tarafından yeniden kullanılır.
class PostCardBottom extends ConsumerWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;

  const PostCardBottom({super.key, required this.post, this.onCommentTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.spotId != null || post.spotDistrict != null) ...[
            _SpotChip(post: post),
            const SizedBox(height: 8),
          ],

          if (post.fishSpecies != null && post.fishSpecies!.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.fishSpecies!
                  .map(
                    (s) => Chip(
                      label: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.foam,
                        ),
                      ),
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],

          if (post.caption != null && post.caption!.isNotEmpty) ...[
            Text(
              post.caption!,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.foam,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],

          _ActionRow(post: post, onCommentTap: onCommentTap),
        ],
      ),
    );
  }
}

// ── Yazar avatar ──────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;

  const _AuthorAvatar({this.avatarUrl, required this.username});

  @override
  Widget build(BuildContext context) {
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';
    ImageProvider? image;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      final url = avatarUrl!.startsWith('http')
          ? avatarUrl!
          : '${dotenv.env['SUPABASE_URL'] ?? ''}/storage/v1/object/public/${avatarStorageBucket()}/$avatarUrl';
      image = NetworkImage(url);
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: const TextStyle(
                color: AppColors.foam,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }
}

// ── Mera chip ─────────────────────────────────────────────────────────────────

class _SpotChip extends StatelessWidget {
  final PostModel post;

  const _SpotChip({required this.post});

  @override
  Widget build(BuildContext context) {
    final label = post.displaySpotName;
    if (label.isEmpty) return const SizedBox.shrink();

    switch (post.spotPrivacySnapshot) {
      case SpotPrivacyLevel.public:
      case SpotPrivacyLevel.friends:
        final isPublic = post.spotPrivacySnapshot == SpotPrivacyLevel.public;
        return GestureDetector(
          onTap: post.spotId != null
              ? () => context.go(AppRoutes.home, extra: post.spotId)
              : null,
          child: _SpotChipContent(
            label: label,
            color: isPublic ? AppColors.primary : AppColors.secondary,
            icon: Icons.place_rounded,
          ),
        );

      case SpotPrivacyLevel.private:
        return _SpotChipContent(
          label: label,
          color: AppColors.muted,
          icon: Icons.lock_outline_rounded,
        );

      case SpotPrivacyLevel.vip:
        return _SpotChipContent(
          label: label,
          color: AppColors.accent,
          icon: Icons.workspace_premium_rounded,
        );
    }
  }
}

class _SpotChipContent extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SpotChipContent({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aksiyon satırı ────────────────────────────────────────────────────────────

class _ActionRow extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;

  const _ActionRow({required this.post, this.onCommentTap});

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _liking = false;

  @override
  Widget build(BuildContext context) {
    final likedAsync = ref.watch(likedPostsProvider(widget.post.id));
    final isLiked = likedAsync.valueOrNull ?? false;

    return Row(
      children: [
        // Beğeni — 48dp dokunma hedefi
        SizedBox(
          height: 48,
          child: TextButton.icon(
            onPressed: _liking ? null : () => _toggleLike(isLiked),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? AppColors.danger : AppColors.muted,
              size: 22,
            ),
            label: Text(
              '${widget.post.likesCount}',
              style: TextStyle(
                color: isLiked ? AppColors.danger : AppColors.muted,
                fontSize: 15,
              ),
            ),
          ),
        ),

        // Yorum
        SizedBox(
          height: 48,
          child: TextButton.icon(
            onPressed: widget.onCommentTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.muted,
              size: 22,
            ),
            label: Text(
              '${widget.post.commentsCount}',
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
        ),

        const Spacer(),
      ],
    );
  }

  Future<void> _toggleLike(bool currentlyLiked) async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final userMeta = ref.read(currentUserProvider)?.userMetadata;
      final myUsername = userMeta?['username'] as String?;
      await repo.toggleLike(
        widget.post.id,
        postOwnerId: widget.post.userId,
        actorUsername: myUsername,
      );
      ref.invalidate(likedPostsProvider(widget.post.id));
      ref.invalidate(friendsFeedProvider);
      ref.invalidate(globalFeedProvider);
    } catch (_) {
      // Sessizce başarısız
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}

// ── "..." menüsü ──────────────────────────────────────────────────────────────

class _PostMenu extends ConsumerWidget {
  final String postId;

  const _PostMenu({required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: AppColors.muted),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Sil', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value != 'delete') return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gönderiyi Sil'),
            content: const Text('Bu gönderiyi silmek istiyor musun?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Sil',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        try {
          await ref.read(postRepositoryProvider).deletePost(postId);
          ref.invalidate(friendsFeedProvider);
          ref.invalidate(globalFeedProvider);
        } catch (_) {}
      },
    );
  }
}
