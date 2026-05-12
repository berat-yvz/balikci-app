import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/error_message_helper.dart';
import 'package:balikci_app/core/utils/time_utils.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';

/// Tekil yorum satırı — akış sheet'i ve gönderi detayı ortak kullanır.
class CommentListTile extends ConsumerWidget {
  final CommentModel comment;

  const CommentListTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = (comment.username?.isNotEmpty ?? false)
        ? comment.username![0].toUpperCase()
        : '?';

    ImageProvider<Object>? image;
    if (comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty) {
      final url = comment.avatarUrl!.startsWith('http')
          ? comment.avatarUrl!
          : '${dotenv.env['SUPABASE_URL'] ?? ''}/storage/v1/object/public/${avatarStorageBucket()}/${comment.avatarUrl}';
      image = NetworkImage(url);
    }

    final myId = SupabaseService.auth.currentUser?.id;

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
          if (myId != null && comment.userId == myId)
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(commentRepositoryProvider)
                        .deleteComment(comment.id);
                    ref.invalidate(postCommentsProvider(comment.postId));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ErrorMessageHelper.toUserMessage(
                            e,
                            fallback: 'Yorum silinemedi.',
                          ),
                        ),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
                tooltip: 'Yorumu sil',
              ),
            ),
        ],
      ),
    );
  }
}
