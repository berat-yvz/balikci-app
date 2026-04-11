import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

/// ADIM 7: Sıralama ekranı — podiyum widget, sticky kendi satırı.
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Sıralama'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.leaderboard_outlined, size: 20), text: 'Genel'),
              Tab(icon: Icon(Icons.date_range_outlined, size: 20), text: 'Haftalık'),
              Tab(
                  icon: Icon(Icons.location_on_outlined, size: 20),
                  text: 'Bölge'),
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
      loading: () => const LoadingWidget(message: 'Sıralamalar yükleniyor...'),
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
      loading: () =>
          const LoadingWidget(message: 'Haftalık sıralama yükleniyor...'),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(weeklyLeaderboardProvider),
      ),
    );
  }
}

// ── Bölge sekmesi ─────────────────────────────────────────────────────────────

class _RegionalTab extends StatelessWidget {
  const _RegionalTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      emoji: '🗺️',
      message: 'Bölge sıralaması yakında!\n'
          'Konumunuza göre kişiselleştirilmiş sıralama eklenecek.',
    );
  }
}

// ── ADIM 7: Podiyum + liste birleşik görünüm ──────────────────────────────────

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
    // Kendi sırasını bul
    final selfIndex =
        currentUserId != null ? users.indexWhere((u) => u.id == currentUserId) : -1;
    final selfUser = selfIndex >= 0 ? users[selfIndex] : null;

    final top3 = users.take(3).toList();
    final rest = users.skip(3).toList();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              slivers: [
                // Podiyum widget (ilk 3)
                if (top3.length >= 2)
                  SliverToBoxAdapter(
                    child: _PodiumWidget(top3: top3, scoreLabel: scoreLabel),
                  ),

                // Header label
                if (headerLabel != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        headerLabel!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),

                // 4. sıradan itibaren liste
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final u = rest[index];
                      final rank = index + 4;
                      final isHighlight =
                          currentUserId != null && u.id == currentUserId;
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    childCount: rest.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),

        // ADIM 7: Sticky kendi satırı (turuncu aksan)
        if (selfUser != null && selfIndex >= 3)
          _StickyOwnRow(
            rank: selfIndex + 1,
            username: selfUser.username,
            avatarUrl: selfUser.avatarUrl,
            rankLabel: selfUser.rank,
            scoreText: scoreLabel(selfUser),
          ),
      ],
    );
  }
}

// Haftalık için ayrı view (WeeklyRankEntry tipini kullanır)
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

    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              slivers: [
                if (top3.length >= 2)
                  SliverToBoxAdapter(
                    child: _WeeklyPodiumWidget(top3: top3),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Son 7 günün en aktif balıkçıları',
                      style:
                          AppTextStyles.caption.copyWith(color: AppColors.muted),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final e = rest[index];
                      final rank = index + 4;
                      final isHighlight =
                          currentUserId != null && e.userId == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    childCount: rest.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
        if (selfEntry != null && selfIndex >= 3)
          _StickyOwnRow(
            rank: selfIndex + 1,
            username: selfEntry.username,
            avatarUrl: selfEntry.avatarUrl,
            rankLabel: selfEntry.rank,
            scoreText: '${selfEntry.checkinCount} bildirim',
          ),
      ],
    );
  }
}

// ── ADIM 7: Podiyum widget (1-2-3) ───────────────────────────────────────────

class _PodiumWidget extends StatelessWidget {
  final List<dynamic> top3;
  final String Function(dynamic u) scoreLabel;

  const _PodiumWidget({required this.top3, required this.scoreLabel});

  @override
  Widget build(BuildContext context) {
    final heights = [80.0, 100.0, 60.0]; // 2. yer, 1. yer, 3. yer
    final order = [1, 0, 2]; // görüntüleme sırası: 2., 1., 3.
    final medals = ['🥇', '🥈', '🥉'];
    final podiumColors = [
      const Color(0xFFFFD700),
      const Color(0xFFB0BEC5),
      const Color(0xFFCD7F32),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Podiyum sütunları
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: order.map((realIdx) {
              if (realIdx >= top3.length) return const Expanded(child: SizedBox());
              final u = top3[realIdx];
              final color = podiumColors[realIdx];
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Madalya + avatar
                    Text(medals[realIdx], style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: realIdx == 0 ? 28 : 22,
                      backgroundImage: u.avatarUrl != null
                          ? NetworkImage(u.avatarUrl!)
                          : null,
                      backgroundColor: AppColors.surface,
                      child: u.avatarUrl == null
                          ? Icon(Icons.person,
                              size: realIdx == 0 ? 28 : 22,
                              color: AppColors.muted)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      u.username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: realIdx == 0 ? 14 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoreLabel(u),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Podiyum sütun yüksekliği
                    Container(
                      height: heights[realIdx],
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        border: Border.all(
                            color: color.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${realIdx + 1}.',
                          style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPodiumWidget extends StatelessWidget {
  final List<WeeklyRankEntry> top3;
  const _WeeklyPodiumWidget({required this.top3});

  @override
  Widget build(BuildContext context) {
    return _PodiumWidget(
      top3: top3,
      scoreLabel: (e) => '${(e as WeeklyRankEntry).checkinCount} bildirim',
    );
  }
}

// ── ADIM 7: Tek satır — 60dp yükseklik ───────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60, // ADIM 7: her satır 60dp
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.secondary.withValues(alpha: 0.12)
            : const Color(0xFF12233A),
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppColors.secondary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: AppColors.surface,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 20, color: AppColors.muted)
                : null,
          ),
          const SizedBox(width: 10),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  scoreText,
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          RankBadge(rank: rankLabel, size: RankBadgeSize.small),
        ],
      ),
    );
  }
}

// ── ADIM 7: Sticky kendi satırı (turuncu aksan) ───────────────────────────────

class _StickyOwnRow extends StatelessWidget {
  final int rank;
  final String username;
  final String? avatarUrl;
  final String rankLabel;
  final String scoreText;

  const _StickyOwnRow({
    required this.rank,
    required this.username,
    required this.avatarUrl,
    required this.rankLabel,
    required this.scoreText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$rank. sıradasın',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor: AppColors.surface,
              child: avatarUrl == null
                  ? const Icon(Icons.person, size: 18, color: AppColors.muted)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              scoreText,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
