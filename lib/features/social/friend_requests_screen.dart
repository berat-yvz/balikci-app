import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';

/// Gelen arkadaşlık istekleri.
class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomingRequestsWithProfilesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('İstekler')),
      body: async.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text(
                'Bekleyen istek yok.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.muted,
                  fontSize: 16,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(incomingRequestsWithProfilesProvider);
              ref.invalidate(incomingFriendRequestsProvider);
              ref.invalidate(mutualFriendsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final row = rows[i];
                final u = row.user;
                final name = u?.username ?? 'Balıkçı';
                final avatar = u?.avatarUrl;
                return Card(
                  color: const Color(0xFF132236),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? NetworkImage(_publicAvatarUrl(avatar))
                                : null,
                            child: avatar == null || avatar.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'Arkadaşlık isteği gönderdi',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          onTap: u != null
                              ? () => context.push('${AppRoutes.profile}/${u.id}')
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  final repo =
                                      ref.read(friendRequestRepositoryProvider);
                                  try {
                                    await repo.acceptRequest(row.req.id);
                                    if (context.mounted) {
                                      ref.invalidate(
                                        incomingRequestsWithProfilesProvider,
                                      );
                                      ref.invalidate(incomingFriendRequestsProvider);
                                      ref.invalidate(mutualFriendsProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Arkadaşlık kabul edildi'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$e'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Kabul et'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final repo =
                                      ref.read(friendRequestRepositoryProvider);
                                  try {
                                    await repo.rejectRequest(row.req.id);
                                    if (context.mounted) {
                                      ref.invalidate(
                                        incomingRequestsWithProfilesProvider,
                                      );
                                      ref.invalidate(incomingFriendRequestsProvider);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$e'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Reddet'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
              'Yüklenemedi: $e',
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
