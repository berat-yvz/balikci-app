import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/widgets/comment_list_tile.dart';
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
    if (content.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorum en fazla 500 karakter olabilir.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(commentRepositoryProvider)
          .addComment(
            postId: widget.post.id,
            content: content,
            postOwnerId: widget.post.userId,
          );
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.post.id));
      ref.invalidate(globalFeedProvider);
      ref.invalidate(friendsFeedProvider);
      ref.invalidate(userPostsProvider(widget.post.userId));
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
      appBar: AppBar(title: Text(widget.post.authorUsername ?? 'Gönderi')),
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
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                    )
                  else
                    ...comments.map((c) => CommentListTile(comment: c)),

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
                        maxLength: 500,
                        decoration: InputDecoration(
                          counterText: '',
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
