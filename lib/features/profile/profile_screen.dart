import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/favorite_provider.dart';
import 'package:balikci_app/shared/providers/fish_log_provider.dart';
import 'package:balikci_app/shared/providers/follow_provider.dart';
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

  static const _avatarBucket = 'users-avatars';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final viewedUserId = widget.userId ?? currentUser?.id;

    final isSelf = widget.userId == null && currentUser != null;
    final isViewingOther = widget.userId != null && viewedUserId != null;

    if (viewedUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = isSelf
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(viewedUserId));

    final isFollowingAsync = isViewingOther
        ? ref.watch(isFollowingProvider(viewedUserId))
        : null;

    return Scaffold(
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
            isFollowingAsync: isFollowingAsync,
            isUploadingAvatar: _uploadingAvatar,
            onPickAvatar: isSelf ? () => _pickAndUploadAvatar(user) : null,
            onFollowToggle: isViewingOther
                ? (willFollow) => _toggleFollow(viewedUserId, willFollow)
                : null,
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

  Future<void> _toggleFollow(String targetUserId, bool willFollow) async {
    final notifier = ref.read(followNotifierProvider.notifier);
    if (willFollow) {
      await notifier.follow(targetUserId);
    } else {
      await notifier.unfollow(targetUserId);
    }
  }

  Future<void> _pickAndUploadAvatar(UserModel user) async {
    setState(() => _uploadingAvatar = true);
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final fileSize = await file.length();
      if (fileSize > 2 * 1024 * 1024) {
        throw Exception(
          'Fotoğraf çok büyük. Lütfen 2MB altında bir fotoğraf seç.',
        );
      }

      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath =
          'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.storage
          .from(_avatarBucket)
          .upload(storagePath, file);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avatar güncellenemedi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }
}

class _ProfileContent extends ConsumerWidget {
  static const _avatarBucket = 'users-avatars';

  final UserModel user;
  final bool isSelf;
  final AsyncValue<bool>? isFollowingAsync;
  final bool isUploadingAvatar;
  final VoidCallback? onPickAvatar;
  final Future<void> Function(bool willFollow)? onFollowToggle;

  const _ProfileContent({
    required this.user,
    required this.isSelf,
    required this.isFollowingAsync,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = _initials(user.username);

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(favoriteSpotsProvider);
      },
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: onPickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(_toPublicAvatarUrl(user.avatarUrl!))
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.dark,
                                ),
                              )
                            : null,
                      ),
                      if (onPickAvatar != null)
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: isUploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.username, style: AppTextStyles.h2),
                const SizedBox(height: 8),
                RankBadge(rank: user.rank, size: RankBadgeSize.large),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
          _SectionTitle(title: 'Rütbe İlerlemesi'),
          const SizedBox(height: 10),
          _RankProgress(currentRank: user.rank, totalScore: user.totalScore),
          const SizedBox(height: 18),
          _SectionTitle(title: 'İstatistikler'),
          const SizedBox(height: 10),
          _StatsRow(userId: user.id, isSelf: isSelf),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Hızlı İşlemler'),
          const SizedBox(height: 10),
          if (isSelf) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.go(AppRoutes.fishLog),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Günlüğüm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2F47),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.push(AppRoutes.fishLogStats),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('İstatistik'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Ayarlar'),
              ),
            ),
          ] else ...[
            if (isFollowingAsync != null)
              isFollowingAsync!.when(
                data: (following) {
                  final willFollow = !following;
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onFollowToggle == null
                          ? null
                          : () => onFollowToggle!(willFollow),
                      icon: Icon(
                        following ? Icons.person_remove : Icons.person_add,
                      ),
                      label: Text(following ? 'Takipten çık' : 'Takip et'),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  width: double.infinity,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Takip et'),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
          ],
          // Favori meralar sadece kendi profilinde görünür
          if (isSelf) ...[
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Favori Meralarım'),
            const SizedBox(height: 10),
            const _FavoriteSpotsSection(),
          ],
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
    return '$base/storage/v1/object/public/$_avatarBucket/$avatarUrlOrPath';
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

class _StatsRow extends ConsumerWidget {
  final String userId;
  final bool isSelf;

  const _StatsRow({required this.userId, required this.isSelf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final fishRepo = ref.watch(fishLogRepositoryProvider);

    return FutureBuilder<List<int>>(
      future: Future.wait([
        userRepo.getFollowerCount(userId),
        userRepo.getFollowingCount(userId),
        fishRepo.getLogCount(userId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            'İstatistikler yüklenemedi.',
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          );
        }

        final followerCount = snapshot.data![0];
        final followingCount = snapshot.data![1];
        final logCount = snapshot.data![2];

        return Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.group_outlined,
                label: 'Takipçi',
                value: followerCount.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                icon: Icons.people_alt_outlined,
                label: 'Takip Edilen',
                value: followingCount.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                icon: Icons.list_alt_outlined,
                label: 'Av Sayısı',
                value: logCount.toString(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF132236),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
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
          onTap: () => context.go(AppRoutes.map, extra: spot.id),
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
