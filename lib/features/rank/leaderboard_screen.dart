import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

/// Genel sıralama — büyük dokunma alanları, açık arka plan, okunaklı tipografi.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String? _rankFilter;

  Future<void> _reloadLeaderboard() async {
    ref.invalidate(leaderboardFilteredProvider(_rankFilter));
    ref.invalidate(myLeaderboardRankProvider);
    await ref.read(leaderboardFilteredProvider(_rankFilter).future);
    await ref.read(myLeaderboardRankProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(leaderboardFilteredProvider(_rankFilter));
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final myRankAsync = ref.watch(myLeaderboardRankProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.foam,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sıralama',
              style: AppTextStyles.h2.copyWith(color: AppColors.foam),
            ),
            const SizedBox(height: 4),
            Text(
              'En çok puan kazanan balıkçılar',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.foam,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RankFilterRow(
            selected: _rankFilter,
            onChanged: (v) => setState(() => _rankFilter = v),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _OwnRankCard(
                profileAsync: profileAsync,
                rankAsync: myRankAsync,
              ),
            ),
          Expanded(
            child: listAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return _EmptyLeaderboard(onRetry: _reloadLeaderboard);
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _reloadLeaderboard,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: users.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.muted.withValues(alpha: 0.35),
                    ),
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final pos = index + 1;
                      return LeaderboardTile(
                        position: pos,
                        user: u,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil yakında!'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, stackTrace) => _LeaderboardError(
                message: _errorMessage(e),
                onRetry: _reloadLeaderboard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _errorMessage(Object e) {
  final s = e.toString();
  if (s.contains('Exception:')) {
    return s.replaceFirst('Exception:', '').trim();
  }
  return 'Sıralama yüklenemedi. Bağlantınızı kontrol edin.';
}

class _RankFilterRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _RankFilterRow({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            _FilterButton(
              label: 'Tümü',
              emoji: '',
              value: null,
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterButton(
              label: 'Acemi',
              emoji: '🪝 ',
              value: 'acemi',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterButton(
              label: 'Olta Kurdu',
              emoji: '🎣 ',
              value: 'olta_kurdu',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterButton(
              label: 'Usta',
              emoji: '⚓ ',
              value: 'usta',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterButton(
              label: 'Deniz Reisi',
              emoji: '🌊 ',
              value: 'deniz_reisi',
              selected: selected,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final String emoji;
  final String? value;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterButton({
    required this.label,
    required this.emoji,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = selected == value;
    final textStyle = AppTextStyles.body.copyWith(
      fontWeight: FontWeight.w700,
      color: isOn ? AppColors.foam : AppColors.primary,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 56),
        child: isOn
            ? FilledButton(
                onPressed: () => onChanged(value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.foam,
                  minimumSize: const Size(44, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('$emoji$label', style: textStyle),
              )
            : OutlinedButton(
                onPressed: () => onChanged(value),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  minimumSize: const Size(44, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '$emoji$label',
                  style: textStyle.copyWith(color: AppColors.primary),
                ),
              ),
      ),
    );
  }
}

class _OwnRankCard extends StatelessWidget {
  final AsyncValue<UserModel?> profileAsync;
  final AsyncValue<int?> rankAsync;

  const _OwnRankCard({
    required this.profileAsync,
    required this.rankAsync,
  });

  @override
  Widget build(BuildContext context) {
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const SizedBox.shrink();
        }
        return rankAsync.when(
          data: (rank) => _card(context, profile, rank),
          loading: () => _card(context, profile, null, loadingRank: true),
          error: (error, stackTrace) => _card(context, profile, null),
        );
      },
      loading: () => const SizedBox(
        height: 96,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _card(
    BuildContext context,
    UserModel profile,
    int? rank, {
    bool loadingRank = false,
  }) {
    return Material(
      color: AppColors.leaderboardBanner,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Senin sıran',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.foam,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: loadingRank
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.foam,
                          ),
                        )
                      : Text(
                          rank != null ? '#$rank' : '—',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.foam,
                            fontSize: 22,
                          ),
                        ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.35),
                  backgroundImage: profile.avatarUrl != null &&
                          profile.avatarUrl!.isNotEmpty
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null ||
                          profile.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 28,
                          color: AppColors.foam,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.foam,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RankBadge(rank: profile.rank, size: RankBadgeSize.small),
                    ],
                  ),
                ),
                Text(
                  '${profile.totalScore}',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.foam,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek sıra — tıklanınca SnackBar (profil yakında).
class LeaderboardTile extends StatelessWidget {
  final int position;
  final UserModel user;
  final VoidCallback onTap;

  const LeaderboardTile({
    super.key,
    required this.position,
    required this.user,
    required this.onTap,
  });

  static String _medalEmoji(int pos) {
    switch (pos) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  static Color? _accentForPosition(int pos) {
    switch (pos) {
      case 1:
        return AppColors.accent;
      case 2:
        return AppColors.muted;
      case 3:
        return AppColors.sand;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medalEmoji(position);
    final accent = _accentForPosition(position);
    final rankStyle = AppTextStyles.h3.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: accent ?? Colors.black87,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 56,
                  child: Center(
                    child: Text(
                      medal.isNotEmpty ? '$medal $position' : '$position',
                      style: rankStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.secondary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          color: Colors.black87,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RankBadge(rank: user.rank, size: RankBadgeSize.small),
                    ],
                  ),
                ),
                Text(
                  '${user.totalScore}',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyLeaderboard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phishing,
              size: 80,
              color: AppColors.secondary.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz sıralama yok',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk check-in\'i sen yap!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.foam,
                ),
                child: Text(
                  'Yenile',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foam,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LeaderboardError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 72,
              color: AppColors.danger.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.foam,
                ),
                child: Text(
                  'Tekrar Dene',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.foam,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
