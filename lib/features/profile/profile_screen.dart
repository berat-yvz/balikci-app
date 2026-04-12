import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/storage_buckets.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/utils/avatar_image_prepare.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/favorite_provider.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // diğer kullanıcı profili için

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _imagePicker = ImagePicker();
  bool _uploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final viewedUserId = widget.userId ?? currentUser?.id;

    final isSelf = widget.userId == null && currentUser != null;

    if (viewedUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = isSelf
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(viewedUserId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: profileAsync.when(
          data: (u) => Text(
            widget.userId != null && u != null ? u.username : 'Profil',
          ),
          loading: () => const Text('Profil'),
          error: (error, stack) => const Text('Profil'),
        ),
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }

          return _ProfileContent(
            user: user,
            isSelf: isSelf,
            isUploadingAvatar: _uploadingAvatar,
            onPickAvatar: isSelf ? () => _pickAndUploadAvatar(user) : null,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Profil yüklenemedi: $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(UserModel user) async {
    setState(() => _uploadingAvatar = true);
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await prepareAvatarUploadBytes(picked);
      final storagePath =
          'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bucket = avatarStorageBucket();
      await SupabaseService.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final repo = ref.read(userRepositoryProvider);
      await repo.updateProfile(userId: user.id, avatarUrl: storagePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar güncellendi ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final bucket = avatarStorageBucket();
      final err = e.toString();
      final isBucketMissing =
          err.contains('Bucket not found') || err.contains('404');
      final message = isBucketMissing
          ? 'Avatar depolama hazır değil. Supabase → SQL: '
              'supabase/migrations/20260411_storage_users_avatars_bucket.sql '
              'dosyasını çalıştırın veya .env içinde SUPABASE_AVATAR_BUCKET ile '
              'mevcut bucket adını yazın. (Aranan: $bucket)'
          : 'Avatar güncellenemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }
}

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  final bool isSelf;
  final bool isUploadingAvatar;
  final VoidCallback? onPickAvatar;

  const _ProfileContent({
    required this.user,
    required this.isSelf,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = _initials(user.username);

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(favoriteSpotsProvider);
        ref.invalidate(mutualFriendCountForUserProvider(user.id));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ADIM 9: Profil başlığı — avatar + rank_badge yan yana
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: onPickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(_toPublicAvatarUrl(user.avatarUrl!))
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: AppColors.dark,
                                  ),
                                )
                              : null,
                        ),
                        if (onPickAvatar != null)
                          Positioned(
                            top: 0,
                            right: -4,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary,
                              child: isUploadingAvatar
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RankBadge(
                        rank: user.rank,
                        size: RankBadgeSize.medium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(user.username, style: AppTextStyles.h2),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ADIM 9: Arkadaş sayısı (karşılıklı takip)
            _FriendsStatRow(userId: user.id),
            const SizedBox(height: 20),

            // ADIM 9: Özet istatistik kartları 3'lü grid
            _SummaryStatsGrid(userId: user.id),
            const SizedBox(height: 20),

            _SectionTitle(title: 'Rütbe İlerlemesi'),
            const SizedBox(height: 10),
            _RankProgress(currentRank: user.rank, totalScore: user.totalScore),
            const SizedBox(height: 20),

            _SectionTitle(title: 'Skorlar'),
            const SizedBox(height: 10),
            _ScoreRow(
              totalScore: user.totalScore,
              sustainabilityScore: user.sustainabilityScore,
              onTapTotal: () {
                _showExplanation(
                  context,
                  'Toplam puan nedir?',
                  'Balık bildirimi, doğru rapor oyları ve günlük kayıtlar puan kazandırır. Toplam puan rütbeni belirler.',
                );
              },
              onTapSustainability: () {
                _showExplanation(
                  context,
                  'Sürdürülebilirlik puanı nedir?',
                  'Balığı geri saldığın kayıtlar sürdürülebilirlik puanını artırır. Bu sayede “♻️” skorun yükselir.',
                );
              },
            ),

            if (isSelf) ...[
              const SizedBox(height: 20),
              // ADIM 9: “Günlüğüm”, “Rozetlerim”, “Ayarlar” alt bölümleri
              _ProfileActionSection(
                onGoToLog: () => context.go(AppRoutes.fishLog),
                onGoToStats: () => context.push(AppRoutes.fishLogStats),
                onGoToSettings: () => context.push(AppRoutes.settings),
              ),
            ] else ...[
              const SizedBox(height: 16),
              ref.watch(socialEdgeProvider(user.id)).when(
                    data: (edge) => _FriendshipActionBar(user: user, edge: edge),
                    loading: () => const SizedBox(
                      width: double.infinity,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Durum yüklenemedi: $e',
                        style: const TextStyle(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
            ],

            if (isSelf) ...[
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Favori Meralarım'),
              const SizedBox(height: 10),
              const _FavoriteSpotsSection(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _initials(String username) {
    final parts = username.trim().split(RegExp(r'\s+'));
    final a = parts.isNotEmpty ? parts.first[0] : 'U';
    final b = parts.length > 1
        ? parts.last[0]
        : (username.isNotEmpty ? username[0] : 'U');
    return (a + b).toUpperCase();
  }

  String _toPublicAvatarUrl(String avatarUrlOrPath) {
    if (avatarUrlOrPath.startsWith('http')) return avatarUrlOrPath;
    final base = dotenv.env['SUPABASE_URL'] ?? '';
    if (base.isEmpty) return avatarUrlOrPath;
    final b = avatarStorageBucket();
    return '$base/storage/v1/object/public/$b/$avatarUrlOrPath';
  }

  void _showExplanation(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int totalScore;
  final int sustainabilityScore;
  final VoidCallback onTapTotal;
  final VoidCallback onTapSustainability;

  const _ScoreRow({
    required this.totalScore,
    required this.sustainabilityScore,
    required this.onTapTotal,
    required this.onTapSustainability,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapTotal,
            child: Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Puan',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('🎣', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          totalScore.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapSustainability,
            child: Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sürdürülebilirlik',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('♻️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          sustainabilityScore.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankProgress extends StatelessWidget {
  final String currentRank;
  final int totalScore;

  const _RankProgress({required this.currentRank, required this.totalScore});

  @override
  Widget build(BuildContext context) {
    // Eşikler score-calculator Edge Function ile birebir uyumlu:
    // acemi=0, olta_kurdu=500, usta=2000, deniz_reisi=5000
    final thresholds = <String, int>{
      'acemi': 500,
      'olta_kurdu': 2000,
      'usta': 5000,
      'deniz_reisi': 5000,
    };

    final lower = switch (currentRank) {
      'acemi' => 0,
      'olta_kurdu' => 500,
      'usta' => 2000,
      'deniz_reisi' => 5000,
      _ => 0,
    };

    final next = thresholds[currentRank];
    if (currentRank == 'deniz_reisi' || next == null) {
      return Card(
        color: const Color(0xFF132236),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deniz Reisi rütbesindesin.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: 1,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ],
          ),
        ),
      );
    }

    final progressRange = next - lower;
    final progressValue = progressRange <= 0
        ? 1.0
        : ((totalScore - lower).clamp(0, progressRange)) / progressRange;

    final xpToNext = (next - totalScore).clamp(0, next);
    final nextRank = switch (currentRank) {
      'acemi' => 'Olta Kurdu (500 puan)',
      'olta_kurdu' => 'Usta (2.000 puan)',
      'usta' => 'Deniz Reisi (5.000 puan)',
      _ => 'Olta Kurdu',
    };

    return Card(
      color: const Color(0xFF132236),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Şu an: ${_rankLabel(currentRank)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Sonraki: $nextRank. $xpToNext puan kaldı.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _rankLabel(String rank) {
    switch (rank) {
      case 'acemi':
        return 'Acemi';
      case 'olta_kurdu':
        return 'Olta Kurdu';
      case 'usta':
        return 'Usta';
      case 'deniz_reisi':
        return 'Deniz Reisi';
      default:
        return rank;
    }
  }
}

// ── Arkadaşlık eylemleri (başka kullanıcı profili) ────────────────────────────

class _FriendshipActionBar extends ConsumerWidget {
  final UserModel user;
  final SocialEdge edge;

  const _FriendshipActionBar({required this.user, required this.edge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (edge.kind) {
      case SocialEdgeKind.self:
        return const SizedBox.shrink();
      case SocialEdgeKind.mutualFriend:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Arkadaşsın'),
          ),
        );
      case SocialEdgeKind.outgoingPending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.schedule),
              label: const Text('İstek gönderildi'),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(friendRequestRepositoryProvider)
                    .cancelOutgoing(user.id);
                ref.invalidate(socialEdgeProvider(user.id));
              },
              child: const Text('İsteği geri al'),
            ),
          ],
        );
      case SocialEdgeKind.incomingPending:
        final id = edge.incomingRequestId;
        return Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: id == null
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(friendRequestRepositoryProvider)
                              .acceptRequest(id);
                          final me = ref.read(currentUserProvider)?.id;
                          if (me != null) {
                            await NotificationRepository().sendNotification(
                              userId: user.id,
                              title: '🤝 Arkadaşlık kabul edildi',
                              body:
                                  'Bir balıkçı arkadaşlık isteğini kabul etti.',
                              data: {
                                'type': 'follow',
                                'follower_id': me,
                              },
                            );
                          }
                          ref.invalidate(socialEdgeProvider(user.id));
                          ref.invalidate(mutualFriendsProvider);
                          ref.invalidate(incomingRequestsWithProfilesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Arkadaşlık kabul edildi'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
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
                onPressed: id == null
                    ? null
                    : () async {
                        await ref
                            .read(friendRequestRepositoryProvider)
                            .rejectRequest(id);
                        ref.invalidate(socialEdgeProvider(user.id));
                        ref.invalidate(incomingRequestsWithProfilesProvider);
                      },
                child: const Text('Reddet'),
              ),
            ),
          ],
        );
      case SocialEdgeKind.stranger:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(friendRequestRepositoryProvider)
                    .sendRequest(user.id);
                final me = ref.read(currentUserProvider)?.id;
                if (me != null) {
                  await NotificationRepository().sendNotification(
                    userId: user.id,
                    title: '👤 Arkadaşlık isteği',
                    body: 'Bir balıkçı seninle arkadaş olmak istiyor.',
                    data: {
                      'type': 'follow_request',
                      'follower_id': me,
                    },
                  );
                }
                ref.invalidate(socialEdgeProvider(user.id));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Arkadaşlık isteği gönderildi'),
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
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Arkadaşlık isteği gönder'),
          ),
        );
    }
  }
}

// ── ADIM 9: Arkadaş sayısı (liste: Sosyal > Arkadaşlarım veya başka profil) ──

class _FriendsStatRow extends ConsumerWidget {
  final String userId;

  const _FriendsStatRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final isSelf = me == userId;
    final async = ref.watch(mutualFriendCountForUserProvider(userId));

    return async.when(
      data: (count) {
        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (isSelf) {
                context.push(AppRoutes.socialFriends);
              } else {
                context.push(AppRoutes.socialFriends, extra: userId);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Arkadaş',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

// ── ADIM 9: Özet istatistik kartları 3'lü grid ───────────────────────────────

class _SummaryStatsGrid extends ConsumerStatefulWidget {
  final String userId;
  const _SummaryStatsGrid({required this.userId});

  static Future<int> _getSpotCount(String userId) async {
    try {
      final rows = await SupabaseService.client
          .from('fishing_spots')
          .select('id')
          .eq('user_id', userId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _getCheckinCount(String userId) async {
    try {
      final rows = await SupabaseService.client
          .from('checkins')
          .select('id')
          .eq('user_id', userId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  ConsumerState<_SummaryStatsGrid> createState() => _SummaryStatsGridState();
}

class _SummaryStatsGridState extends ConsumerState<_SummaryStatsGrid> {
  Future<List<int>>? _statsFuture;

  @override
  void didUpdateWidget(covariant _SummaryStatsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _statsFuture = null;
    }
  }

  Future<List<int>> _loadStats() {
    final fishRepo = ref.read(fishLogRepositoryProvider);
    return Future.wait([
      fishRepo.getLogCount(widget.userId),
      _SummaryStatsGrid._getSpotCount(widget.userId),
      _SummaryStatsGrid._getCheckinCount(widget.userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fishLogRepositoryProvider);
    _statsFuture ??= _loadStats();

    return FutureBuilder<List<int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final logCount = snapshot.data?[0] ?? 0;
        final spotCount = snapshot.data?[1] ?? 0;
        final checkinCount = snapshot.data?[2] ?? 0;

        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                emoji: '🐟',
                value: '$logCount',
                label: 'Toplam Kayıt',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                emoji: '📍',
                value: '$spotCount',
                label: 'Toplam Mera',
                onTap: () => context.push(
                  AppRoutes.profileUserSpots(widget.userId),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                emoji: '🎣',
                value: '$checkinCount',
                label: 'Bildirimlerim',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.emoji,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF132236),
        borderRadius: radius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: child,
      ),
    );
  }
}

// ── ADIM 9: Profil aksiyon bölümleri ─────────────────────────────────────────

class _ProfileActionSection extends StatelessWidget {
  final VoidCallback onGoToLog;
  final VoidCallback onGoToStats;
  final VoidCallback onGoToSettings;

  const _ProfileActionSection({
    required this.onGoToLog,
    required this.onGoToStats,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.menu_book_rounded,
          label: 'Günlüğüm',
          subtitle: 'Avladığın balıkları gör',
          onTap: onGoToLog,
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.bar_chart_rounded,
          label: 'İstatistiklerim',
          subtitle: 'Av grafikleri ve sürdürülebilirlik',
          onTap: onGoToStats,
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.settings_outlined,
          label: 'Ayarlar',
          subtitle: 'Hesap ve uygulama ayarları',
          onTap: onGoToSettings,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF132236),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.muted.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Favori Meralar Bölümü ────────────────────────────────────────────────────

class _FavoriteSpotsSection extends ConsumerWidget {
  const _FavoriteSpotsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(favoriteSpotsProvider);

    return spotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        'Favoriler yüklenemedi: $e',
        style: const TextStyle(color: AppColors.danger, fontSize: 14),
      ),
      data: (spots) {
        if (spots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF132236),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_border, color: AppColors.muted),
                const SizedBox(width: 12),
                Text(
                  'Henüz favori mera yok.',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          );
        }

        return Column(
          children: spots
              .map((spot) => _FavoriteSpotTile(spot: spot))
              .toList(),
        );
      },
    );
  }
}

class _FavoriteSpotTile extends StatelessWidget {
  final SpotModel spot;
  const _FavoriteSpotTile({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(AppRoutes.home, extra: spot.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132236),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  color: AppColors.sand,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spot.type != null)
                        Text(
                          spot.type!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
