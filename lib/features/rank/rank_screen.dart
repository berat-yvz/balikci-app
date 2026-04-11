import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/region_leaderboard_regions.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';
import 'package:balikci_app/shared/widgets/skeleton_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

/// Sıralama ekranı — tek sütun liste, okunaklı tipografi (45+ hedef kitle).
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  static const _tabTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Sıralama'),
          bottom: TabBar(
            labelStyle: _tabTextStyle,
            unselectedLabelStyle:
                _tabTextStyle.copyWith(fontWeight: FontWeight.w500),
            labelColor: AppColors.foam,
            unselectedLabelColor: AppColors.muted,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                height: 52,
                icon: Icon(Icons.leaderboard_outlined, size: 22),
                text: 'Genel',
              ),
              Tab(
                height: 52,
                icon: Icon(Icons.date_range_outlined, size: 22),
                text: 'Haftalık',
              ),
              Tab(
                height: 52,
                icon: Icon(Icons.location_on_outlined, size: 22),
                text: 'Bölge',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AllTimeTab(),
            _WeeklyTab(),
            _RegionalTab(),
          ],
        ),
      ),
    );
  }
}

// ── Genel sıralama ────────────────────────────────────────────────────────────

class _AllTimeTab extends ConsumerWidget {
  const _AllTimeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncUsers = ref.watch(leaderboardProvider);

    return asyncUsers.when(
      data: (users) {
        if (users.isEmpty) {
          return const _EmptyState(emoji: '🏆', message: 'Henüz sıralama verisi yok.');
        }
        return _LeaderboardView(
          users: users,
          currentUserId: currentUserId,
          scoreLabel: (u) => '${u.totalScore} puan',
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          headerLabel: 'Toplam puana göre sıralama',
        );
      },
      loading: () => const SkeletonList(
        itemCount: 8,
        hasLeadingCircle: true,
        hasTrailing: true,
      ),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(leaderboardProvider),
      ),
    );
  }
}

// ── Haftalık sıralama ─────────────────────────────────────────────────────────

class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncWeekly = ref.watch(weeklyLeaderboardProvider);

    return asyncWeekly.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyState(
            emoji: '📅',
            message: 'Bu hafta henüz bildirim yapılmadı.',
          );
        }
        // WeeklyRankEntry → hafif dönüşüm
        return _WeeklyLeaderboardView(
          entries: entries,
          currentUserId: currentUserId,
          onRefresh: () async => ref.invalidate(weeklyLeaderboardProvider),
        );
      },
      loading: () => const SkeletonList(
        itemCount: 8,
        hasLeadingCircle: true,
        hasTrailing: true,
      ),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(weeklyLeaderboardProvider),
      ),
    );
  }
}

// ── Bölge sekmesi — kutuda mera kaydı olan kullanıcılar (toplam puan) ─────────

class _RegionalTab extends ConsumerStatefulWidget {
  const _RegionalTab();

  @override
  ConsumerState<_RegionalTab> createState() => _RegionalTabState();
}

class _RegionalTabState extends ConsumerState<_RegionalTab> {
  late String _regionKey = kCoastalLeaderboardRegions.first.key;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncUsers = ref.watch(regionalLeaderboardProvider(_regionKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kıyı bölgesi',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.muted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontSize: 17,
                ),
                dropdownColor: const Color(0xFF152A45),
                value: _regionKey,
                items: [
                  for (final r in kCoastalLeaderboardRegions)
                    DropdownMenuItem(
                      value: r.key,
                      child: Text(
                        r.label,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _regionKey = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: asyncUsers.when(
            data: (users) {
              if (users.isEmpty) {
                return const _EmptyState(
                  emoji: '🗺️',
                  message:
                      'Bu bölgede henüz mera kaydı yok.\nİlk merayı sen ekle!',
                );
              }
              return _LeaderboardView(
                users: users,
                currentUserId: currentUserId,
                scoreLabel: (u) => '${u.totalScore} puan',
                onRefresh: () async =>
                    ref.invalidate(regionalLeaderboardProvider(_regionKey)),
                headerLabel:
                    'Bölgede mera ekleyen balıkçılar — toplam puana göre',
              );
            },
            loading: () => const SkeletonList(
              itemCount: 8,
              hasLeadingCircle: true,
              hasTrailing: true,
            ),
            error: (e, _) => AppErrorWidget(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(regionalLeaderboardProvider(_regionKey)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tek sütun liderlik listesi ───────────────────────────────────────────────

class _LeaderboardView extends StatelessWidget {
  final List<dynamic> users;
  final String? currentUserId;
  final String Function(dynamic u) scoreLabel;
  final Future<void> Function() onRefresh;
  final String? headerLabel;

  const _LeaderboardView({
    required this.users,
    required this.currentUserId,
    required this.scoreLabel,
    required this.onRefresh,
    this.headerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final selfIndex =
        currentUserId != null ? users.indexWhere((u) => u.id == currentUserId) : -1;
    final selfUser = selfIndex >= 0 ? users[selfIndex] : null;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              slivers: [
                if (headerLabel != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        headerLabel!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.muted,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final u = users[index];
                        final rank = index + 1;
                        final isHighlight =
                            currentUserId != null && u.id == currentUserId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeaderboardRow(
                            rank: rank,
                            username: u.username,
                            avatarUrl: u.avatarUrl,
                            rankLabel: u.rank,
                            scoreText: scoreLabel(u),
                            highlight: isHighlight,
                          ),
                        );
                      },
                      childCount: users.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
        if (selfUser != null && selfIndex >= 3)
          _StickyOwnRow(
            rank: selfIndex + 1,
            username: selfUser.username,
            avatarUrl: selfUser.avatarUrl,
            scoreText: scoreLabel(selfUser),
          ),
      ],
    );
  }
}

// Haftalık — aynı tek sütun düzeni
class _WeeklyLeaderboardView extends StatelessWidget {
  final List<WeeklyRankEntry> entries;
  final String? currentUserId;
  final Future<void> Function() onRefresh;

  const _WeeklyLeaderboardView({
    required this.entries,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final selfIndex = currentUserId != null
        ? entries.indexWhere((e) => e.userId == currentUserId)
        : -1;
    final selfEntry = selfIndex >= 0 ? entries[selfIndex] : null;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      'Son 7 günün en aktif balıkçıları',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final e = entries[index];
                        final rank = index + 1;
                        final isHighlight =
                            currentUserId != null && e.userId == currentUserId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeaderboardRow(
                            rank: rank,
                            username: e.username,
                            avatarUrl: e.avatarUrl,
                            rankLabel: e.rank,
                            scoreText: '${e.checkinCount} bildirim',
                            highlight: isHighlight,
                          ),
                        );
                      },
                      childCount: entries.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
        if (selfEntry != null && selfIndex >= 3)
          _StickyOwnRow(
            rank: selfIndex + 1,
            username: selfEntry.username,
            avatarUrl: selfEntry.avatarUrl,
            scoreText: '${selfEntry.checkinCount} bildirim',
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String username;
  final String? avatarUrl;
  final String rankLabel;
  final String scoreText;
  final bool highlight;

  const _LeaderboardRow({
    required this.rank,
    required this.username,
    required this.avatarUrl,
    required this.rankLabel,
    required this.scoreText,
    required this.highlight,
  });

  /// İlk üç sıra — yan yana podiyum yerine sol şerit + hafif arka plan.
  static const _topColors = [
    Color(0xFFD4A574),
    Color(0xFF9EB0BF),
    Color(0xFFC17A4A),
  ];

  @override
  Widget build(BuildContext context) {
    final topAccent = rank <= 3 ? _topColors[rank - 1] : null;
    final baseFill = highlight
        ? AppColors.secondary.withValues(alpha: 0.14)
        : (topAccent != null
            ? Color.lerp(const Color(0xFF12233A), topAccent, 0.12)!
            : const Color(0xFF12233A));

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: baseFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.secondary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
          width: highlight ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topAccent != null)
              Container(width: 5, color: topAccent.withValues(alpha: 0.95)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: topAccent ?? AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          avatarUrl != null && avatarUrl!.isNotEmpty
                              ? NetworkImage(avatarUrl!)
                              : null,
                      backgroundColor: AppColors.surface,
                      child: avatarUrl == null || avatarUrl!.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: AppColors.muted,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scoreText,
                            style: TextStyle(
                              color: AppColors.foam.withValues(alpha: 0.82),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: RankBadge(
                          rank: rankLabel,
                          size: RankBadgeSize.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyOwnRow extends StatelessWidget {
  final int rank;
  final String username;
  final String? avatarUrl;
  final String scoreText;

  const _StickyOwnRow({
    required this.rank,
    required this.username,
    required this.avatarUrl,
    required this.scoreText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.secondary.withValues(alpha: 0.18),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.secondary.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank. sıra',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                backgroundColor: AppColors.surface,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? const Icon(Icons.person_rounded,
                        size: 22, color: AppColors.muted)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      scoreText,
                      style: TextStyle(
                        color: AppColors.foam.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Boş durum ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;

  const _EmptyState({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: AppColors.muted,
                fontSize: 17,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
