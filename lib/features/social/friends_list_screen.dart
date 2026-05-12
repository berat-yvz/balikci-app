import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/widgets/network_error_widget.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

String _rankKeyForBadge(String rank) {
  switch (rank) {
    case 'olta_kurdu':
    case 'usta':
    case 'deniz_reisi':
      return rank;
    default:
      return 'acemi';
  }
}

void _openDiscover(BuildContext context) {
  context.push(AppRoutes.socialHub, extra: 1);
}

/// Karşılıklı takip (kabul edilmiş arkadaşlıklar).
/// [forUserId] null → oturumdaki kullanıcı; dolu → o kullanıcının arkadaş listesi.
///
/// [embedded] true ise üst çubuğu olmadan gövde (ör. [FriendsHubScreen] sekmesi).
class FriendsListScreen extends ConsumerWidget {
  final String? forUserId;
  final bool embedded;

  const FriendsListScreen({super.key, this.forUserId, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = forUserId == null
        ? ref.watch(mutualFriendsProvider)
        : ref.watch(mutualFriendsForUserProvider(forUserId!));

    final title = forUserId == null ? 'Arkadaşlarım' : 'Arkadaşlar';
    final emptyOwn =
        'Henüz arkadaşın yok.\nAkışta arkadaşlar düğmesinden balıkçı ekleyebilirsin.';
    final emptyOther = 'Bu kullanıcının henüz arkadaşı yok.';

    final body = async.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    forUserId == null ? emptyOwn : emptyOther,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.muted,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _openDiscover(context),
                      child: const Text('Balıkçı Keşfet →'),
                    ),
                  ),
                ],
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
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            itemCount: users.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i < users.length) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage:
                        u.avatarUrl != null && u.avatarUrl!.isNotEmpty
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
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          u.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RankBadge(
                        rank: _rankKeyForBadge(u.rank),
                        size: RankBadgeSize.compact,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${u.totalScore} puan',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                  ),
                  onTap: () => context.push('${AppRoutes.profile}/${u.id}'),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: OutlinedButton(
                  onPressed: () => _openDiscover(context),
                  child: const Text('Balıkçı Keşfet →'),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => NetworkErrorWidget(
        title: 'Arkadaş listesi yüklenemedi',
        onRetry: () {
          if (forUserId == null) {
            ref.invalidate(mutualFriendsProvider);
          } else {
            ref.invalidate(mutualFriendsForUserProvider(forUserId!));
          }
        },
      ),
    );

    if (embedded) {
      return ColoredBox(color: AppColors.background, child: body);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(title)),
      body: body,
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
