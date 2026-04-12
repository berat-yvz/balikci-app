import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

/// Arkadaşlar / istekler ekranlarıyla aynı kart dolgusu ([FriendRequestsScreen]).
const Color _kSocialCardFill = Color(0xFF132236);

/// Genel sıralama — Topluluk > Arkadaşlar ile aynı tipografi ve liste düzeni.
///
/// [embedded] true iken iç [Scaffold] kullanılmaz (Sosyal > Sıralama sekmesi).
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.embedded = false});

  final bool embedded;

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

  /// [_DiscoverUserTile] bölüm başlıkları ile aynı (13 / muted / w700).
  Widget _sectionIntro() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 10 : 6, 16, 6),
      child: Text(
        'En çok puan kazanan balıkçılar',
        style: TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _bodyColumn(
    AsyncValue<List<UserModel>> listAsync,
    User? user,
    AsyncValue<UserModel?> profileAsync,
    AsyncValue<int?> myRankAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionIntro(),
        _RankFilterRow(
          selected: _rankFilter,
          onChanged: (v) => setState(() => _rankFilter = v),
        ),
        if (user != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: _OwnRankCard(
              profileAsync: profileAsync,
              rankAsync: myRankAsync,
            ),
          ),
        Expanded(
          child: listAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _reloadLeaderboard,
                  child: _EmptyLeaderboard(onRetry: _reloadLeaderboard),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _reloadLeaderboard,
                child: ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: widget.embedded ? 24 : 100,
                  ),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(leaderboardFilteredProvider(_rankFilter));
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final myRankAsync = ref.watch(myLeaderboardRankProvider);

    if (widget.embedded) {
      return ColoredBox(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _bodyColumn(listAsync, user, profileAsync, myRankAsync),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sıralama'),
      ),
      body: _bodyColumn(listAsync, user, profileAsync, myRankAsync),
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
      height: 62,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            _FilterChipButton(
              label: 'Tümü',
              emoji: '',
              value: null,
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterChipButton(
              label: 'Acemi',
              emoji: '🪝 ',
              value: 'acemi',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterChipButton(
              label: 'Olta Kurdu',
              emoji: '🎣 ',
              value: 'olta_kurdu',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterChipButton(
              label: 'Usta',
              emoji: '⚓ ',
              value: 'usta',
              selected: selected,
              onChanged: onChanged,
            ),
            _FilterChipButton(
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

/// Kısayol kartlarına yakın: 12 radius, okunaklı 14sp etiket, min 48dp yükseklik.
class _FilterChipButton extends StatelessWidget {
  final String label;
  final String emoji;
  final String? value;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterChipButton({
    required this.label,
    required this.emoji,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = selected == value;
    final labelText = '$emoji$label';
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: isOn ? FontWeight.w800 : FontWeight.w700,
      color: isOn ? AppColors.foam : Colors.white,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isOn ? AppColors.primary : _kSocialCardFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isOn
                  ? null
                  : Border.all(
                      color: AppColors.muted.withValues(alpha: 0.35),
                    ),
            ),
            alignment: Alignment.center,
            child: Text(labelText, style: labelStyle),
          ),
        ),
      ),
    );
  }
}

/// [FriendRequestsScreen] kartı + [FriendsListScreen] satır tipografisi.
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
        height: 88,
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
    return Card(
      color: _kSocialCardFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Senin sıran',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: loadingRank
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          rank != null ? '#$rank' : '—',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                ),
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: profile.avatarUrl != null &&
                          profile.avatarUrl!.isNotEmpty
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                      ? Text(
                          profile.username.isNotEmpty
                              ? profile.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.totalScore} puan',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RankBadge(rank: profile.rank, size: RankBadgeSize.small),
                    ],
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

Color _rankAccent(int position) {
  switch (position) {
    case 1:
      return AppColors.rankDenizReisi;
    case 2:
      return AppColors.muted;
    case 3:
      return AppColors.sand;
    default:
      return AppColors.muted;
  }
}

String _medalFor(int position) {
  switch (position) {
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

/// [FriendsListScreen] / [_DiscoverUserTile] ile aynı [ListTile] düzeni.
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

  @override
  Widget build(BuildContext context) {
    final medal = _medalFor(position);
    final accent = _rankAccent(position);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minVerticalPadding: 10,
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
            ? Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${user.totalScore} puan',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          RankBadge(rank: user.rank, size: RankBadgeSize.small),
        ],
      ),
      trailing: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (medal.isNotEmpty)
              Text(
                medal,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            Text(
              '#$position',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyLeaderboard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.phishing_rounded,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                'Henüz sıralama yok',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'İlk check-in\'i sen yap!',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
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
      ],
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
              size: 64,
              color: AppColors.danger.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.muted,
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
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
