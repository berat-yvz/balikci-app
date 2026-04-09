import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';

class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sıralama'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.leaderboard_outlined, size: 20),
                text: 'Genel',
              ),
              Tab(
                icon: Icon(Icons.date_range_outlined, size: 20),
                text: 'Haftalık',
              ),
              Tab(
                icon: Icon(Icons.location_on_outlined, size: 20),
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

// ── Genel sıralama (toplam puan) ─────────────────────────────────────────────

class _AllTimeTab extends ConsumerWidget {
  const _AllTimeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncUsers = ref.watch(leaderboardProvider);

    return asyncUsers.when(
      data: (users) {
        if (users.isEmpty) {
          return const _EmptyState(
            emoji: '🏆',
            message: 'Henüz sıralama verisi yok.',
          );
        }
        return _LeaderboardList(
          itemCount: users.length,
          itemBuilder: (idx) {
            final u = users[idx];
            return _LeaderboardRow(
              rank: idx + 1,
              username: u.username,
              avatarUrl: u.avatarUrl,
              rankLabel: u.rank,
              scoreLabel: '${u.totalScore} puan',
              highlight: currentUserId == u.id,
            );
          },
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

// ── Haftalık sıralama (son 7 gün check-in sayısı) ────────────────────────────

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
        return _LeaderboardList(
          itemCount: entries.length,
          itemBuilder: (idx) {
            final e = entries[idx];
            return _LeaderboardRow(
              rank: idx + 1,
              username: e.username,
              avatarUrl: e.avatarUrl,
              rankLabel: e.rank,
              scoreLabel: '${e.checkinCount} bildirim',
              highlight: currentUserId == e.userId,
            );
          },
          onRefresh: () async => ref.invalidate(weeklyLeaderboardProvider),
          headerLabel: 'Son 7 günün en aktif balıkçıları',
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
          'Konumunuza göre kişiselleştirilmiş\n'
          'sıralama eklenecek.',
    );
  }
}

// ── Ortak liste scaffold ──────────────────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int idx) itemBuilder;
  final Future<void> Function() onRefresh;
  final String? headerLabel;

  const _LeaderboardList({
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    this.headerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = headerLabel != null;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: itemCount + (hasHeader ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (hasHeader) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  headerLabel!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            return itemBuilder(index - 1);
          }
          return itemBuilder(index);
        },
      ),
    );
  }
}

// ── Tek satır ─────────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String username;
  final String? avatarUrl;
  final String rankLabel;
  final String scoreLabel;
  final bool highlight;

  const _LeaderboardRow({
    required this.rank,
    required this.username,
    required this.avatarUrl,
    required this.rankLabel,
    required this.scoreLabel,
    required this.highlight,
  });

  static const _medals = ['🥇', '🥈', '🥉'];

  static const _podiumColors = [
    Color(0xFFFFD700), // altın
    Color(0xFFB0BEC5), // gümüş
    Color(0xFFCD7F32), // bronz
  ];

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final podiumColor = isTop3 ? _podiumColors[rank - 1] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : isTop3
                ? podiumColor!.withValues(alpha: 0.08)
                : const Color(0xFF12233A),
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : isTop3
                ? Border.all(
                    color: podiumColor!.withValues(alpha: 0.30),
                  )
                : null,
      ),
      child: Row(
        children: [
          // Sıralama numarası / madalya
          SizedBox(
            width: 36,
            child: isTop3
                ? Text(
                    _medals[rank - 1],
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '$rank.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: AppColors.surface,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 20, color: AppColors.muted)
                : null,
          ),
          const SizedBox(width: 12),
          // Kullanıcı bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: isTop3 ? 15 : 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  scoreLabel,
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          // Rütbe rozeti
          RankBadge(rank: rankLabel, size: RankBadgeSize.small),
        ],
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
