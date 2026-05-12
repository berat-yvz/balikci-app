import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/core/utils/time_utils.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Sosyal akış gönderi kartı — Facebook/Instagram karışımı.
///
/// Çift tıklama ile beğeni, mera header'da, balık türleri fotoğrafın altında.
class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _liking = false;
  late final TapGestureRecognizer _captionAuthorNameTap;

  @override
  void initState() {
    super.initState();
    _captionAuthorNameTap = TapGestureRecognizer()
      ..onTap = () {
        if (!mounted) return;
        context.push('${AppRoutes.profile}/${widget.post.userId}');
      };
  }

  @override
  void dispose() {
    _captionAuthorNameTap.dispose();
    super.dispose();
  }

  void _openAuthorProfile() {
    context.push('${AppRoutes.profile}/${widget.post.userId}');
  }

  /// Bildirim metinleri için veritabanıyla uyumlu görünen ad (teknik kuyruk düşürülür).
  String? _notificationActorName() {
    final u = ref.read(currentUserProvider);
    if (u == null) return null;
    return UserModel.displayUsername(
      rawUsername: u.userMetadata?['username'] as String?,
      email: u.email ?? '',
      userId: u.id,
    );
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final actorName = _notificationActorName();
      await repo.toggleLike(
        widget.post.id,
        postOwnerId: widget.post.userId,
        actorUsername: actorName,
      );
      ref.invalidate(likedPostsProvider(widget.post.id));
      ref.invalidate(globalFeedProvider);
    } catch (_) {
      // Sessizce başarısız
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUserProvider)?.id;
    final isOwner = myUid != null && myUid == widget.post.userId;
    final likedAsync = ref.watch(likedPostsProvider(widget.post.id));
    final isLiked = likedAsync.valueOrNull ?? false;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Header subtitle: "3 saat önce • 📍 MeraAdı"
    final spotLabel =
        (widget.post.spotId != null || widget.post.spotDistrict != null)
        ? widget.post.displaySpotName
        : null;
    final subtitleText = spotLabel != null
        ? '${timeAgo(widget.post.createdAt)} • 📍 $spotLabel'
        : timeAgo(widget.post.createdAt);

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openAuthorProfile,
                    customBorder: const CircleBorder(),
                    child: _AuthorAvatar(
                      avatarUrl: widget.post.authorAvatarUrl,
                      username: widget.post.authorUsername ?? 'Balıkçı',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _openAuthorProfile,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            widget.post.authorUsername ?? 'Balıkçı',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foam,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _PostMenu(post: widget.post, isOwner: isOwner),
              ],
            ),
          ),

          // ── Fotoğraf (çift tıklama ile beğeni) ─────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: _toggleLike,
            child: SizedBox(
              width: double.infinity,
              height: screenWidth * 0.85,
              child: Image.network(
                widget.post.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.muted.withValues(alpha: 0.15),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      size: 48,
                      color: AppColors.muted,
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

          // ── Aksiyon satırı ──────────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  // Beğeni
                  TextButton.icon(
                    onPressed: _liking ? null : _toggleLike,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey<bool>(isLiked),
                        color: isLiked ? Colors.red : AppColors.muted,
                        size: 24,
                      ),
                    ),
                    label: Text(
                      ' ${widget.post.likesCount}',
                      style: TextStyle(
                        color: isLiked ? Colors.red : AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Yorum
                  TextButton.icon(
                    onPressed: widget.onTap,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.muted,
                      size: 24,
                    ),
                    label: Text(
                      ' ${widget.post.commentsCount}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Balık türleri ───────────────────────────────────────────────────
          if (widget.post.fishSpecies != null &&
              widget.post.fishSpecies!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.post.fishSpecies!
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
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
            ),

          // ── Caption — "kullanıcıAdı metin" (Facebook stili) ─────────────────
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.post.authorUsername ?? "Balıkçı"} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.foam,
                      ),
                      recognizer: _captionAuthorNameTap,
                    ),
                    TextSpan(
                      text: widget.post.caption!,
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 15,
                        color: AppColors.foam,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 8),
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

          _DetailActionRow(post: post, onCommentTap: onCommentTap),
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
      radius: 24,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}

// ── Mera chip (PostCardBottom için) ──────────────────────────────────────────

class _SpotChip extends StatelessWidget {
  final PostModel post;

  const _SpotChip({required this.post});

  @override
  Widget build(BuildContext context) {
    final label = post.displaySpotName;
    if (label.isEmpty) return const SizedBox.shrink();

    final Color color;
    final IconData icon;

    switch (post.spotPrivacySnapshot) {
      case SpotPrivacyLevel.public:
        color = AppColors.primary;
        icon = Icons.place_rounded;
      case SpotPrivacyLevel.friends:
        color = AppColors.secondary;
        icon = Icons.place_rounded;
      case SpotPrivacyLevel.private:
        color = AppColors.muted;
        icon = Icons.lock_outline_rounded;
      case SpotPrivacyLevel.vip:
        color = AppColors.accent;
        icon = Icons.workspace_premium_rounded;
    }

    final canTap =
        post.spotId != null &&
        (post.spotPrivacySnapshot == SpotPrivacyLevel.public ||
            post.spotPrivacySnapshot == SpotPrivacyLevel.friends);

    return GestureDetector(
      onTap: canTap
          ? () => context.go(AppRoutes.home, extra: post.spotId)
          : null,
      child: Container(
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
      ),
    );
  }
}

// ── Aksiyon satırı (PostCardBottom / PostDetailScreen için) ──────────────────

class _DetailActionRow extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onCommentTap;

  const _DetailActionRow({required this.post, this.onCommentTap});

  @override
  ConsumerState<_DetailActionRow> createState() => _DetailActionRowState();
}

class _DetailActionRowState extends ConsumerState<_DetailActionRow> {
  bool _liking = false;

  String? _notificationActorName() {
    final u = ref.read(currentUserProvider);
    if (u == null) return null;
    return UserModel.displayUsername(
      rawUsername: u.userMetadata?['username'] as String?,
      email: u.email ?? '',
      userId: u.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedAsync = ref.watch(likedPostsProvider(widget.post.id));
    final isLiked = likedAsync.valueOrNull ?? false;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _liking ? null : () => _toggleLike(isLiked),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey<bool>(isLiked),
                color: isLiked ? Colors.red : AppColors.muted,
                size: 24,
              ),
            ),
            label: Text(
              '${widget.post.likesCount}',
              style: TextStyle(
                color: isLiked ? Colors.red : AppColors.muted,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onCommentTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.muted,
              size: 24,
            ),
            label: Text(
              '${widget.post.commentsCount}',
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ),
          const Spacer(),
          Text(
            timeAgo(widget.post.createdAt),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(bool currentlyLiked) async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final actorName = _notificationActorName();
      await repo.toggleLike(
        widget.post.id,
        postOwnerId: widget.post.userId,
        actorUsername: actorName,
      );
      ref.invalidate(likedPostsProvider(widget.post.id));
      ref.invalidate(globalFeedProvider);
    } catch (_) {
      // Sessizce başarısız
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}

// ── "⋯" menüsü — her kartta; gönderi sahibinde ek olarak Sil ────────────────────

class _PostMenu extends ConsumerWidget {
  final PostModel post;
  final bool isOwner;

  const _PostMenu({required this.post, required this.isOwner});

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
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
            child: const Text('Sil', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (!context.mounted || confirm != true) return;
    try {
      await ref.read(postRepositoryProvider).deletePost(post.id);
      ref.invalidate(globalFeedProvider);
      ref.invalidate(userPostsProvider(post.userId));
      ref.invalidate(likedPostsProvider(post.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gönderi silindi')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageHelper.toUserMessage(
              e,
              fallback: 'Gönderi silinemedi.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Gönderi seçenekleri',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
      color: AppColors.surface,
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            await _confirmAndDelete(context, ref);
          case 'share':
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paylaş özelliği yakında.')),
            );
          case 'report':
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Şikayet özelliği yakında.')),
            );
          default:
            break;
        }
      },
      itemBuilder: (BuildContext ctx) => [
        const PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_outlined),
            title: Text('Paylaş'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'report',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Şikayet Et'),
          ),
        ),
        if (isOwner)
          const PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ),
      ],
    );
  }
}
