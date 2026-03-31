import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/user_provider.dart';
import 'package:balikci_app/shared/widgets/error_widget.dart';
import 'package:balikci_app/shared/widgets/loading_widget.dart';
import 'package:balikci_app/shared/widgets/rank_badge.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
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

    return Scaffold(
      appBar: AppBar(title: const Text('Liderlik')),
      body: asyncUsers.when(
        data: (users) {
          if (!_controller.isAnimating) {
            _controller.forward(from: 0);
          }

          final top3 = users.take(3).toList();
          final rest = users.skip(3).toList();

          return Column(
            children: [
              SizedBox(
                height: 260,
                child: _PodiumSection(
                  top3: top3,
                  currentUserId: currentUserId,
                  animation: _controller,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rest.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final user = rest[idx];
                    final rank = idx + 4;
                    final highlight =
                        currentUserId != null && currentUserId == user.id;
                    return _LeaderboardRow(
                      user: user,
                      rank: rank,
                      highlight: highlight,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(message: 'Liderlik hesaplanıyor...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
      ),
    );
  }
}

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
    final radius = isCenter ? 40.0 : 34.0;
    final badgeSize = isCenter ? RankBadgeSize.medium : RankBadgeSize.small;

    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final v = animation.value;
                final display = (v * rank).round();
                return Text(
                  '$display.',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: isCenter ? 22 : 18,
                    color: highlight ? AppColors.primary : AppColors.dark,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: size,
              width: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: highlight
                            ? AppColors.primary.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: RankBadge(rank: user.rank, size: badgeSize),
                  ),
                  // Kullanıcı foto/avatar yoksa bırakılır; sadece rozet.
                  SizedBox(
                    width: radius,
                    height: radius,
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 150,
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${user.totalScore} puan',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final UserModel user;
  final int rank;
  final bool highlight;

  const _LeaderboardRow({
    required this.user,
    required this.rank,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        children: [
          RankBadge(rank: user.rank, size: RankBadgeSize.small),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${user.username}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toplam puan: ${user.totalScore}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text('${user.totalScore}', style: AppTextStyles.h3),
        ],
      ),
    );
  }
}

class _PodiumPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 62);

    final base = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 260, height: 64),
      base,
    );

    final base2 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 230, height: 52),
      base2,
    );

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 8),
        width: 200,
        height: 44,
      ),
      shadow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
