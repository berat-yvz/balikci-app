import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';

/// Karşılıklı takip (kabul edilmiş arkadaşlıklar).
/// [forUserId] null → oturumdaki kullanıcı; dolu → o kullanıcının arkadaş listesi.
class FriendsListScreen extends ConsumerWidget {
  final String? forUserId;

  const FriendsListScreen({super.key, this.forUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = forUserId == null
        ? ref.watch(mutualFriendsProvider)
        : ref.watch(mutualFriendsForUserProvider(forUserId!));

    final title = forUserId == null ? 'Arkadaşlarım' : 'Arkadaşlar';
    final emptyOwn =
        'Henüz arkadaşın yok.\nTopluluk sekmesinden istek gönderebilirsin.';
    final emptyOther = 'Bu kullanıcının henüz arkadaşı yok.';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: async.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  forUserId == null ? emptyOwn : emptyOther,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              if (forUserId == null) {
                ref.invalidate(mutualFriendsProvider);
              } else {
                ref.invalidate(mutualFriendsForUserProvider(forUserId!));
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: u.avatarUrl != null &&
                            u.avatarUrl!.isNotEmpty
                        ? NetworkImage(_publicAvatarUrl(u.avatarUrl!))
                        : null,
                    child: u.avatarUrl == null || u.avatarUrl!.isEmpty
                        ? Text(
                            u.username.isNotEmpty
                                ? u.username[0].toUpperCase()
                                : '?',
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
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () =>
                      context.push('${AppRoutes.profile}/${u.id}'),
                );
              },
            ),
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
  final bucket = avatarStorageBucket();
  return '$base/storage/v1/object/public/$bucket/$avatarUrlOrPath';
}
