import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/region_leaderboard_regions.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';
import 'package:balikci_app/shared/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gümüş ve bronz sıra vurgusu — AppColors’ta yok; tema dışı tek istisnalar.
const Color _kRankSilverAccent = Color(0xFFAEB8C0);
const Color _kRankBronzeAccent = Color(0xFFB87333);

/// Alt navigasyon: Genel / Haftalık / Bölge sıralamaları.
class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});

  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _rankFilter;
  String _regionKey = kCoastalLeaderboardRegions.first.key;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _invalidateLeaderboards() {
    ref.invalidate(leaderboardProvider);
    ref.invalidate(leaderboardFilteredProvider(_rankFilter));
    ref.invalidate(weeklyLeaderboardProvider);
    ref.invalidate(regionalLeaderboardProvider(_regionKey));
    ref.invalidate(myLeaderboardRankProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🎣 Sıralama',
          style: AppTextStyles.h2.copyWith(color: AppColors.foam),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.foam,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.leaderboard_outlined, size: 24),
              text: 'Genel',
            ),
            Tab(
              icon: Icon(Icons.calendar_view_week_outlined, size: 24),
              text: 'Haftalık',
            ),
            Tab(
              icon: Icon(Icons.map_outlined, size: 24),
              text: 'Bölge',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(
            rankFilter: _rankFilter,
            onRankFilterChanged: (v) => setState(() => _rankFilter = v),
            onRefresh: _invalidateLeaderboards,
          ),
          _WeeklyTab(onRefresh: _invalidateLeaderboards),
          _RegionalTab(
            regionKey: _regionKey,
            onRegionChanged: (k) => setState(() => _regionKey = k),
            onRefresh: _invalidateLeaderboards,
          ),
        ],
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({
    required this.rankFilter,
    required this.onRankFilterChanged,
    required this.onRefresh,
  });

  final String? rankFilter;
  final ValueChanged<String?> onRankFilterChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardFilteredProvider(rankFilter));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final myRankAsync = ref.watch(myLeaderboardRankProvider);

    Future<void> doRefresh() async {
      onRefresh();
      await ref.read(leaderboardFilteredProvider(rankFilter).future);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RankFilterChips(
          selected: rankFilter,
          onChanged: onRankFilterChanged,
        ),
        Expanded(
          child: async.when(
            loading: () => RefreshIndicator(
              onRefresh: doRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: 8,
                itemBuilder: (context, _) => const SkeletonListTile(
                  hasLeadingCircle: true,
                  hasTrailing: true,
                ),
              ),
            ),
            error: (e, _) => RefreshIndicator(
              onRefresh: doRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    child: AppErrorWidget(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(
                        leaderboardFilteredProvider(rankFilter),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            data: (users) {
              if (users.isEmpty) {
                return RefreshIndicator(
                  onRefresh: doRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 48),
                      _EmptyState(
                        message:
                            'Henüz kimse yok. İlk balığını kaydet, listede görün!',
                      ),
                    ],
                  ),
                );
              }
              final selfIndex =
                  users.indexWhere((u) => u.id == currentUserId);
              final showSticky = currentUserId != null && selfIndex >= 3;
              final selfUser = showSticky
                  ? users.firstWhere((u) => u.id == currentUserId)
                  : null;

              final listView = ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeaderboardRow(
                      rank: index + 1,
                      username: u.username,
                      avatarUrl: u.avatarUrl,
                      rankLabel: u.rank,
                      scoreText: '${u.totalScore} puan',
                      highlight: u.id == currentUserId,
                    ),
                  );
                },
              );

              if (!showSticky || selfUser == null) {
                return RefreshIndicator(
                  onRefresh: doRefresh,
                  child: listView,
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: doRefresh,
                      child: listView,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _StickyOwnRow(
                      rankText: myRankAsync.when(
                        data: (r) => '#$r',
                        loading: () => '…',
                        error: (_, stackTrace) => '?',
                      ),
                      username: selfUser.username,
                      avatarUrl: selfUser.avatarUrl,
                      rankLabel: selfUser.rank,
                      scoreText: '${selfUser.totalScore} puan',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyLeaderboardProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    Future<void> doRefresh() async {
      onRefresh();
      await ref.read(weeklyLeaderboardProvider.future);
    }

    return async.when(
      loading: () => RefreshIndicator(
        onRefresh: doRefresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 8,
          itemBuilder: (context, _) => const SkeletonListTile(
            hasLeadingCircle: true,
            hasTrailing: true,
          ),
        ),
      ),
      error: (e, _) => RefreshIndicator(
        onRefresh: doRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(weeklyLeaderboardProvider),
              ),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: doRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 48),
                _EmptyState(
                  message:
                      'Bu hafta henüz check-in yok. Avını kaydet, sıralamaya gir!',
                ),
              ],
            ),
          );
        }
        final selfIndex =
            entries.indexWhere((e) => e.userId == currentUserId);
        final showSticky = currentUserId != null && selfIndex >= 3;
        final selfEntry = showSticky
            ? entries.firstWhere((e) => e.userId == currentUserId)
            : null;

        final listView = ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaderboardRow(
                rank: index + 1,
                username: e.username,
                avatarUrl: e.avatarUrl,
                rankLabel: e.rank,
                scoreText: '${e.checkinCount} bildirim',
                highlight: e.userId == currentUserId,
              ),
            );
          },
        );

        if (!showSticky || selfEntry == null) {
          return RefreshIndicator(
            onRefresh: doRefresh,
            child: listView,
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: doRefresh,
                child: listView,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _StickyOwnRow(
                rankText: '#${selfIndex + 1}',
                username: selfEntry.username,
                avatarUrl: selfEntry.avatarUrl,
                rankLabel: selfEntry.rank,
                scoreText: '${selfEntry.checkinCount} bildirim',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RegionalTab extends ConsumerWidget {
  const _RegionalTab({
    required this.regionKey,
    required this.onRegionChanged,
    required this.onRefresh,
  });

  final String regionKey;
  final ValueChanged<String> onRegionChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(regionalLeaderboardProvider(regionKey));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final regionLabel = kCoastalLeaderboardRegions
        .firstWhere((r) => r.key == regionKey)
        .label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            regionLabel,
            style: AppTextStyles.h3.copyWith(color: AppColors.foam),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final r in kCoastalLeaderboardRegions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _RegionChip(
                    label: r.label,
                    selected: r.key == regionKey,
                    onTap: () => onRegionChanged(r.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              Future<void> doRefresh() async {
                onRefresh();
                await ref.read(regionalLeaderboardProvider(regionKey).future);
              }

              return async.when(
                loading: () => RefreshIndicator(
                  onRefresh: doRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 8,
                    itemBuilder: (context, _) => const SkeletonListTile(
                      hasLeadingCircle: true,
                      hasTrailing: true,
                    ),
                  ),
                ),
                error: (e, _) => RefreshIndicator(
                  onRefresh: doRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.35,
                        child: AppErrorWidget(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(
                            regionalLeaderboardProvider(regionKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (users) {
                  if (users.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: doRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 32),
                          _EmptyState(
                            message:
                                'Bu bölgede henüz kimse yok. İlk sen ol!',
                          ),
                        ],
                      ),
                    );
                  }
                  final selfIndex =
                      users.indexWhere((u) => u.id == currentUserId);
                  final showSticky = currentUserId != null && selfIndex >= 3;
                  final selfUser = showSticky
                      ? users.firstWhere((u) => u.id == currentUserId)
                      : null;

                  final listView = ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LeaderboardRow(
                          rank: index + 1,
                          username: u.username,
                          avatarUrl: u.avatarUrl,
                          rankLabel: u.rank,
                          scoreText: '${u.totalScore} puan',
                          highlight: u.id == currentUserId,
                        ),
                      );
                    },
                  );

                  if (!showSticky || selfUser == null) {
                    return RefreshIndicator(
                      onRefresh: doRefresh,
                      child: listView,
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: doRefresh,
                          child: listView,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _StickyOwnRow(
                          rankText: '#${selfIndex + 1}',
                          username: selfUser.username,
                          avatarUrl: selfUser.avatarUrl,
                          rankLabel: selfUser.rank,
                          scoreText: '${selfUser.totalScore} puan',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RankFilterChips extends StatelessWidget {
  const _RankFilterChips({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _chips = <({String label, String? value})>[
    (label: 'Tümü', value: null),
    (label: '🪝 Acemi', value: 'acemi'),
    (label: '🎣 Olta Kurdu', value: 'olta_kurdu'),
    (label: '⚓ Usta', value: 'usta'),
    (label: '🌊 Deniz Reisi', value: 'deniz_reisi'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          for (final c in _chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: c.label,
                selected: selected == c.value,
                onTap: () => onChanged(c.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? null
                : Border.all(color: AppColors.muted, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.foam,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? null
                : Border.all(color: AppColors.muted, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.foam,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🐟', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.username,
    required this.avatarUrl,
    required this.rankLabel,
    required this.scoreText,
    required this.highlight,
  });

  final int rank;
  final String username;
  final String? avatarUrl;
  final String rankLabel;
  final String scoreText;
  final bool highlight;

  Color _accentForRank(int r) {
    return switch (r) {
      1 => AppColors.rankDenizReisi,
      2 => _kRankSilverAccent,
      3 => _kRankBronzeAccent,
      _ => AppColors.foam,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForRank(rank);
    final borderColor = highlight
        ? AppColors.primary.withValues(alpha: 0.60)
        : AppColors.foam.withValues(alpha: 0.07);
    final bgColor = highlight
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.surface;

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: highlight ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.muted.withValues(alpha: 0.35),
            backgroundImage:
                avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    username.isNotEmpty
                        ? username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.foam,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
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
                  username,
                  style: const TextStyle(
                    color: AppColors.foam,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    RankBadge(
                      rank: rankLabel,
                      size: RankBadgeSize.small,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scoreText,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyOwnRow extends StatelessWidget {
  const _StickyOwnRow({
    required this.rankText,
    required this.username,
    required this.avatarUrl,
    required this.rankLabel,
    required this.scoreText,
  });

  final String rankText;
  final String username;
  final String? avatarUrl;
  final String rankLabel;
  final String scoreText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: AppColors.primary, width: 1),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Senin sıran $rankText',
                  style: TextStyle(
                    color: AppColors.foam.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: const TextStyle(
                    color: AppColors.foam,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.foam.withValues(alpha: 0.25),
            backgroundImage:
                avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    username.isNotEmpty
                        ? username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.foam,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RankBadge(
                rank: rankLabel,
                size: RankBadgeSize.small,
              ),
              const SizedBox(height: 4),
              Text(
                scoreText,
                style: const TextStyle(
                  color: AppColors.foam,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
