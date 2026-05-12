import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/widgets/comment_list_tile.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Feed kartından açılan yorum alt sayfası.
Future<void> showPostCommentsSheet(
  BuildContext context,
  WidgetRef ref,
  PostModel post,
) async {
  final height = MediaQuery.sizeOf(context).height * 0.6;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: _PostCommentsSheetBody(post: post),
        ),
      );
    },
  );
}

class _PostCommentsSheetBody extends ConsumerStatefulWidget {
  final PostModel post;

  const _PostCommentsSheetBody({required this.post});

  @override
  ConsumerState<_PostCommentsSheetBody> createState() =>
      _PostCommentsSheetBodyState();
}

class _PostCommentsSheetBodyState
    extends ConsumerState<_PostCommentsSheetBody> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
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
      _controller.clear();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Yorumlar',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.foam,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Kapat',
                icon: const Icon(Icons.close, color: AppColors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (error, stackTrace) => const Center(
              child: Text(
                'Yorumlar yüklenemedi.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Henüz yorum yok. İlk yorumu sen yaz!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: comments.length,
                itemBuilder: (_, i) => CommentListTile(comment: comments[i]),
              );
            },
          ),
        ),
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
                      controller: _controller,
                      maxLength: 500,
                      maxLines: 1,
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
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.foam,
                          ),
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'Gönder',
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
