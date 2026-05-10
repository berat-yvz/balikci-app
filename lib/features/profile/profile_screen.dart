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
import 'package:balikci_app/core/widgets/network_error_widget.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/data/repositories/notification_repository.dart';
import 'package:balikci_app/data/models/post_model.dart';
import 'package:balikci_app/features/feed/screens/post_detail_screen.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/favorite_provider.dart';
import 'package:balikci_app/shared/providers/friend_request_provider.dart';
import 'package:balikci_app/shared/providers/post_provider.dart';
import 'package:balikci_app/shared/providers/profile_summary_stats_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/data/repositories/shadow_point_repository.dart';
import 'package:balikci_app/features/profile/widgets/how_to_earn_points_sheet.dart';
import 'package:balikci_app/features/profile/widgets/shadow_point_history_sheet.dart';
import 'package:balikci_app/shared/providers/shadow_point_provider.dart';
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

    UserModel? provisional;
    if (isSelf) {
      provisional = UserModel.provisionalSelf(
        id: currentUser.id,
        email: currentUser.email ?? '',
        userMetadata: currentUser.userMetadata,
        createdAtIso: currentUser.createdAt,
      );
    }

    final loaded = profileAsync.asData?.value;
    final resolvedUser = loaded ?? (profileAsync.isLoading ? provisional : null);

    final needsBlockingSpinner =
        resolvedUser == null && profileAsync.isLoading && provisional == null;
    final showError =
        profileAsync.hasError && resolvedUser == null && provisional == null;
    final showMissing =
        profileAsync.hasValue && loaded == null && provisional == null;

    late final Widget body;
    if (showError) {
      body = NetworkErrorWidget(
        title: 'Profil yüklenemedi',
        onRetry: () {
          if (isSelf) {
            ref.invalidate(currentUserProfileProvider);
          } else {
            ref.invalidate(userProfileProvider(viewedUserId));
          }
        },
      );
    } else if (needsBlockingSpinner) {
      body = const Center(child: CircularProgressIndicator());
    } else if (showMissing) {
      body = const Center(child: Text('Kullanıcı bulunamadı.'));
    } else {
      final displayUser = resolvedUser!;
      body = _ProfileContent(
        user: displayUser,
        isSelf: isSelf,
        isUploadingAvatar: _uploadingAvatar,
        onPickAvatar:
            isSelf ? () => _pickAndUploadAvatar(displayUser) : null,
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.userId != null && resolvedUser != null
              ? resolvedUser.username
              : 'Profil',
        ),
      ),
      body: body,
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
        final uid = user.id;
        if (isSelf) {
          ref.invalidate(currentUserProfileProvider);
          ref.invalidate(favoriteSpotsProvider);
          ref.invalidate(shadowPointSummaryProvider(uid));
          ref.invalidate(recentShadowEventsProvider(uid));
        } else {
          ref.invalidate(userProfileProvider(uid));
          ref.invalidate(socialEdgeProvider(uid));
        }
        ref.invalidate(mutualFriendCountForUserProvider(uid));
        ref.invalidate(profileSummaryStatsProvider(uid));
        await ref.read(userPostsProvider(uid).notifier).refresh(uid);
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
            _RankProgress(
              currentRank: user.rank,
              totalScore: user.totalScore,
              showHowToEarnButton: isSelf,
              shadowSummaryUserId: isSelf ? user.id : null,
            ),
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
                  'Balık bildirimi, doğru rapor oyları ve sosyal gönderiler puan kazandırır. Toplam puan rütbeni belirler.',
                );
              },
              onTapSustainability: () {
                _showExplanation(
                  context,
                  'Sürdürülebilirlik puanı nedir?',
                  'Çevre dostu davranışların ve aktivitelerin sürdürülebilirlik puanını etkiler. Bu sayede “♻️” skorun yükselir.',
                );
              },
            ),

            if (isSelf) ...[
              const SizedBox(height: 20),
              _ActionTile(
                icon: Icons.settings_outlined,
                label: 'Ayarlar',
                subtitle: 'Hesap ve uygulama ayarları',
                onTap: () => context.push(AppRoutes.settings),
              ),
            ] else ...[
              const SizedBox(height: 16),
              ref.watch(socialEdgeProvider(user.id)).when(
                    data: (edge) => _FriendshipActionBar(user: user, edge: edge),
                    loading: () => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(minHeight: 3),
                      ),
                    ),
                    error: (e, _) => SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Arkadaşlık durumu alınamadı',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],

            // Gönderi grid'i — her kullanıcı profili için
            const SizedBox(height: 24),
            _SectionTitle(title: 'Gönderileri'),
            const SizedBox(height: 10),
            _PostGridSection(userId: user.id),

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

/// score-calculator rütbe eşikleri ile uyumlu (min/max aralığı).
class _RankThresholdData {
  final int min;
  final int max;
  final String next;

  const _RankThresholdData(this.min, this.max, this.next);
}

const Map<String, _RankThresholdData> _rankThresholds = {
  'acemi': _RankThresholdData(0, 500, 'Olta Kurdusu'),
  'olta_kurdu': _RankThresholdData(500, 2000, 'Usta Balıkçı'),
  'usta': _RankThresholdData(2000, 5000, 'Deniz Reisi'),
  'deniz_reisi': _RankThresholdData(5000, 5000, ''),
};

class _ShadowPointCard extends StatelessWidget {
  final ShadowPointSummary summary;
  final String userId;

  const _ShadowPointCard({
    required this.summary,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ShadowPointHistorySheet(userId: userId),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gölge Puanın',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '+${summary.total} puan',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${summary.eventCount} kez meranı kullanan oldu',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankProgress extends ConsumerWidget {
  final String currentRank;
  final int totalScore;
  final bool showHowToEarnButton;
  final String? shadowSummaryUserId;

  const _RankProgress({
    required this.currentRank,
    required this.totalScore,
    this.showHowToEarnButton = false,
    this.shadowSummaryUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = _rankThresholds[currentRank] ?? _rankThresholds['acemi']!;
    final isDenizReisi = currentRank == 'deniz_reisi';

    final double progress;
    if (isDenizReisi) {
      progress = 1.0;
    } else {
      final span = band.max - band.min;
      progress = span <= 0
          ? 1.0
          : (totalScore - band.min) / span;
    }
    final clampedProgress = progress.clamp(0.0, 1.0);

    final remainingScore = isDenizReisi
        ? 0
        : (band.max - totalScore).clamp(0, band.max);

    return Card(
      color: AppColors.leaderboardBanner,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDenizReisi
                  ? 'Deniz Reisi rütbesindesin.'
                  : 'Şu an: ${_rankLabel(currentRank)}',
              style: const TextStyle(
                color: AppColors.foam,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: clampedProgress,
                minHeight: 10,
                backgroundColor: AppColors.surface,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            if (isDenizReisi)
              const Text(
                'En yüksek rütbeye ulaştın! 🌊',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                '${band.next} için $remainingScore puan daha kazan',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            if (shadowSummaryUserId != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ref
                    .watch(shadowPointSummaryProvider(shadowSummaryUserId!))
                    .when(
                      data: (summary) => summary.total > 0
                          ? _ShadowPointCard(
                              summary: summary,
                              userId: shadowSummaryUserId!,
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
              ),
            ],
            if (showHowToEarnButton) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
                label: const Text(
                  'Nasıl puan kazanırım?',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const HowToEarnPointsSheet(),
                ),
              ),
            ],
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

// ── ADIM 9: Arkadaş sayısı (liste: akış > arkadaşlar veya başka profil) ──

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

class _SummaryStatsGrid extends ConsumerWidget {
  final String userId;
  const _SummaryStatsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileSummaryStatsProvider(userId));
    return async.when(
      loading: () => _SummaryStatsPlaceholderRow(userId: userId),
      error: (Object error, StackTrace stackTrace) => _SummaryStatsValuesRow(
        userId: userId,
        posts: '—',
        spots: '—',
        checkins: '—',
      ),
      data: (s) => _SummaryStatsValuesRow(
        userId: userId,
        posts: '${s.postCount}',
        spots: '${s.spotCount}',
        checkins: '${s.checkinCount}',
      ),
    );
  }
}

class _SummaryStatsPlaceholderRow extends StatelessWidget {
  final String userId;
  const _SummaryStatsPlaceholderRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return _SummaryStatsValuesRow(
      userId: userId,
      posts: '…',
      spots: '…',
      checkins: '…',
    );
  }
}

class _SummaryStatsValuesRow extends StatelessWidget {
  final String userId;
  final String posts;
  final String spots;
  final String checkins;

  const _SummaryStatsValuesRow({
    required this.userId,
    required this.posts,
    required this.spots,
    required this.checkins,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            emoji: '📸',
            value: posts,
            label: 'Gönderiler',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            emoji: '📍',
            value: spots,
            label: 'Toplam Mera',
            onTap: () => context.push(
              AppRoutes.profileUserSpots(userId),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            emoji: '🎣',
            value: checkins,
            label: 'Bildirimlerim',
          ),
        ),
      ],
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
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          const Text(
            'Favoriler yüklenemedi',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
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

// ── Gönderi Grid Bölümü ───────────────────────────────────────────────────────

class _PostGridSection extends ConsumerWidget {
  final String userId;

  const _PostGridSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (_, _) => Text(
        'Gönderiler yüklenemedi',
        style: TextStyle(color: AppColors.muted, fontSize: 14),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Henüz gönderi yok',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          );
        }

        final visible = posts.take(9).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 1,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final post = visible[index];
                return _PostGridTile(post: post);
              },
            ),
            if (posts.length > 9) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    // Şimdilik aynı listeyi gösterir; FAZ 4'te ayrı ekran
                  },
                  child: const Text('Tümünü Gör'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PostGridTile extends StatelessWidget {
  final PostModel post;

  const _PostGridTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            post.photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.surface,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
