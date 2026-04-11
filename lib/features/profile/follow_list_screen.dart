import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/data/repositories/follow_repository.dart';

/// Takipçi veya takip edilen kullanıcı listesi.
enum FollowListMode { followers, following }

/// Anahtar: `{userId}|followers` veya `{userId}|following`
final _followListProvider =
    FutureProvider.autoDispose.family<List<UserModel>, String>((ref, key) async {
  final segs = key.split('|');
  if (segs.length < 2) return const <UserModel>[];
  final userId = segs.first;
  final mode = segs.last == 'followers'
      ? FollowListMode.followers
      : FollowListMode.following;
  final followRepo = FollowRepository();
  final userRepo = ref.read(userRepositoryProvider);
  final ids = mode == FollowListMode.followers
      ? await followRepo.getFollowerIds(userId)
      : await followRepo.getFollowingIds(userId);
  if (ids.isEmpty) return const <UserModel>[];
  return userRepo.getProfilesByIds(ids);
});

class FollowListScreen extends ConsumerWidget {
  final String userId;
  final FollowListMode mode;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = mode == FollowListMode.followers ? 'Takipçiler' : 'Takip edilenler';
    final cacheKey =
        '$userId|${mode == FollowListMode.followers ? 'followers' : 'following'}';
    final async = ref.watch(_followListProvider(cacheKey));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: async.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                mode == FollowListMode.followers
                    ? 'Henüz takipçi yok.'
                    : 'Kimseyi takip etmiyor.',
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: u.avatarUrl != null
                      ? NetworkImage(_publicAvatarUrl(u.avatarUrl!))
                      : null,
                  child: u.avatarUrl == null
                      ? Text(
                          u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  u.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${u.totalScore} puan',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  if (u.id == userId) {
                    context.pop();
                    return;
                  }
                  context.push('${AppRoutes.profile}/${u.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Liste yüklenemedi: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}

String _publicAvatarUrl(String avatarUrlOrPath) {
  if (avatarUrlOrPath.startsWith('http')) return avatarUrlOrPath;
  final base = dotenv.env['SUPABASE_URL'] ?? '';
  if (base.isEmpty) return avatarUrlOrPath;
  const bucket = 'users-avatars';
  return '$base/storage/v1/object/public/$bucket/$avatarUrlOrPath';
}
