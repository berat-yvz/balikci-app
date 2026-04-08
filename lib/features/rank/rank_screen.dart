import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
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
              Tab(text: 'Genel'),
              Tab(text: 'Haftalık'),
              Tab(text: 'Bölge'),
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

// ── Genel sıralama (toplam puan) — podium + liste ────────────────────────────

class _AllTimeTab extends ConsumerStatefulWidget {
  const _AllTimeTab();

  @override
  ConsumerState<_AllTimeTab> createState() => _AllTimeTabState();
}

class _AllTimeTabState extends ConsumerState<_AllTimeTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final asyncUsers = ref.watch(leaderboardProvider);

    return asyncUsers.when(
      data: (users) {
        if (!_controller.isCompleted) _controller.forward(from: 0);

        final top3 = users.take(3).toList();
        final rest = users.skip(3).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          child: CustomScrollView(
            slivers: [
              // Podium bölümü
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: _PodiumSection(
                    top3: top3,
                    currentUserId: currentUserId,
                    animation: _controller,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              // 4. ve sonrası liste
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: rest.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final u = rest[idx];
                    return _LeaderboardRow(
                      rank: idx + 4,
                      username: u.username,
                      avatarUrl: u.avatarUrl,
                      rankLabel: u.rank,
                      scoreLabel: '${u.totalScore} puan',
                      highlight: currentUserId == u.id,
                    );
                  },
                ),
              ),
            ],
          ),
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

// ── Podium widget'ları ────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  final List<UserModel> top3;
  final String? currentUserId;
  final Animation<double> animation;

  const _PodiumSection({
    required this.top3,
    required this.currentUserId,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final rank1 = top3.isNotEmpty ? top3[0] : null;
    final rank2 = top3.length > 1 ? top3[1] : null;
    final rank3 = top3.length > 2 ? top3[2] : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _PodiumPainter())),
        if (rank2 != null)
          _PodiumPerson(
            user: rank2,
            rank: 2,
            align: Alignment.centerLeft,
            animation: animation,
            highlight: currentUserId == rank2.id,
          ),
        if (rank1 != null)
          _PodiumPerson(
            user: rank1,
            rank: 1,
            align: Alignment.center,
            animation: animation,
            highlight: currentUserId == rank1.id,
            isCenter: true,
          ),
        if (rank3 != null)
          _PodiumPerson(
            user: rank3,
            rank: 3,
            align: Alignment.centerRight,
            animation: animation,
            highlight: currentUserId == rank3.id,
          ),
      ],
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  final UserModel user;
  final int rank;
  final Alignment align;
  final Animation<double> animation;
  final bool highlight;
  final bool isCenter;

  const _PodiumPerson({
    required this.user,
    required this.rank,
    required this.align,
    required this.animation,
    required this.highlight,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCenter ? 84.0 : 68.0;
    final badgeSize = isCenter ? RankBadgeSize.medium : RankBadgeSize.small;
    final medal = ['🥇', '🥈', '🥉'][rank - 1];

    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(medal, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            SizedBox(
              height: size,
              width: size,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.scale(
                  scale: Curves.elasticOut.transform(animation.value),
                  child: child,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12233A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: highlight
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.muted.withValues(alpha: 0.2),
                      width: highlight ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: user.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              user.avatarUrl!,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  RankBadge(rank: user.rank, size: badgeSize),
                            ),
                          )
                        : RankBadge(rank: user.rank, size: badgeSize),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: isCenter ? 15 : 13,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${user.totalScore} puan',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 62);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 260, height: 64),
      Paint()
        ..color = AppColors.primaryLight
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 230, height: 52),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          currentUserId: currentUserId,
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
  final String? currentUserId;
  final int itemCount;
  final Widget Function(int idx) itemBuilder;
  final Future<void> Function() onRefresh;
  final String? headerLabel;

  const _LeaderboardList({
    required this.currentUserId,
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    this.headerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount + (headerLabel != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (headerLabel != null) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : const Color(0xFF12233A),
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        children: [
          // Sıralama numarası
          SizedBox(
            width: 36,
            child: rank <= 3
                ? Text(
                    ['🥇', '🥈', '🥉'][rank - 1],
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
          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
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
