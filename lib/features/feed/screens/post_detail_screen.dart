import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/core/utils/time_utils.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/widgets/post_card.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Gönderi detay ekranı — büyük fotoğraf, yorumlar, yorum girişi.
class PostDetailScreen extends ConsumerStatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addComment(
            postId: widget.post.id,
            content: content,
            postOwnerId: widget.post.userId,
          );
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.post.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessageHelper.toUserMessage(
              e,
              fallback: 'Yorum gönderilemedi. Tekrar dene.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.post.id));
    final comments = commentsAsync.valueOrNull ?? [];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.post.authorUsername ?? 'Gönderi'),
      ),
      body: Column(
        children: [
          // Ana içerik kaydırılabilir
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zoom destekli fotoğraf
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.network(
                        widget.post.photoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: AppColors.surface,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.muted,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Alt bölüm (mera, türler, caption, aksiyon)
                  PostCardBottom(post: widget.post),

                  const Divider(height: 1, thickness: 1),

                  // Yorumlar başlığı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Yorumlar (${widget.post.commentsCount})',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.foam,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Yorum listesi
                  if (commentsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Henüz yorum yok. İlk yorumu sen yap!',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ...comments.map((c) => _CommentTile(comment: c)),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Yorum giriş alanı — alt sabit
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Yorum yaz...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.muted.withValues(alpha: 0.4),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      onPressed: _sending ? null : _sendComment,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.foam,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.foam,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yorum satırı ─────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final initials =
        (comment.username?.isNotEmpty ?? false)
            ? comment.username![0].toUpperCase()
            : '?';

    ImageProvider? image;
    if (comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty) {
      final url = comment.avatarUrl!.startsWith('http')
          ? comment.avatarUrl!
          : '${dotenv.env['SUPABASE_URL'] ?? ''}/storage/v1/object/public/${avatarStorageBucket()}/${comment.avatarUrl}';
      image = NetworkImage(url);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: image,
            child: image == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.foam,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username ?? 'Kullanıcı',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foam,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.foam,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Kendi yorumu için sil butonu
          if (comment.userId ==
              SupabaseService.auth.currentUser?.id)
            _DeleteCommentButton(comment: comment),
        ],
      ),
    );
  }

}

// ── Yorum sil butonu ─────────────────────────────────────────────────────────

class _DeleteCommentButton extends ConsumerWidget {
  final CommentModel comment;

  const _DeleteCommentButton({required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: () async {
          try {
            await SupabaseService.client
                .from('post_comments')
                .delete()
                .eq('id', comment.id);
            ref.invalidate(postCommentsProvider(comment.postId));
          } catch (_) {}
        },
        icon: const Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: AppColors.muted,
        ),
        tooltip: 'Yorumu sil',
      ),
    );
  }
}
