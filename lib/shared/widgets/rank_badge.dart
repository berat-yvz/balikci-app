import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

enum RankBadgeSize { small, medium, large }

class RankBadge extends StatefulWidget {
  final String rank;
  final RankBadgeSize size;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = RankBadgeSize.medium,
  });

  @override
  State<RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<RankBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isDenizReisi => widget.rank == 'deniz_reisi';

  @override
  Widget build(BuildContext context) {
    final cfg = _badgeConfig(widget.rank, widget.size);

    final child = _isDenizReisi
        ? _DenizReisiShimmerBadge(
            controller: _controller,
            child: cfg.child,
          )
        : cfg.child;

    return child;
  }

  _BadgeConfig _badgeConfig(String rank, RankBadgeSize size) {
    final isSmall = size == RankBadgeSize.small;
    final isLarge = size == RankBadgeSize.large;

    final double padV = isSmall ? 6 : (isLarge ? 12 : 9);
    final double padH = isSmall ? 10 : (isLarge ? 14 : 12);
    final double fontSize = isSmall ? 13 : (isLarge ? 18 : 15);
    final double iconSize = isSmall ? 16 : (isLarge ? 22 : 18);

    switch (rank) {
      case 'acemi':
        return _BadgeConfig(
          background: AppColors.muted.withValues(alpha: 0.15),
          border: Colors.transparent,
          color: AppColors.muted,
          child: _chip(
            emoji: '🪝',
            text: 'Acemi',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            borderColor: Colors.transparent,
            backgroundColor: AppColors.muted.withValues(alpha: 0.15),
            textColor: AppColors.muted,
          ),
        );
      case 'olta_kurdu':
        return _BadgeConfig(
          background: AppColors.secondary.withValues(alpha: 0.15),
          border: Colors.transparent,
          color: AppColors.secondary,
          child: _chip(
            emoji: '🎣',
            text: 'Olta Kurdu',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            borderColor: Colors.transparent,
            backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
            textColor: AppColors.secondary,
          ),
        );
      case 'usta':
        return _BadgeConfig(
          background: AppColors.primary.withValues(alpha: 0.10),
          border: AppColors.primary,
          color: AppColors.primary,
          child: _chip(
            emoji: '⚓',
            text: 'Usta',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            borderColor: AppColors.primary,
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            textColor: AppColors.primary,
          ),
        );
      case 'deniz_reisi':
      default:
        return _BadgeConfig(
          background: Colors.amber.withValues(alpha: 0.18),
          border: Colors.amber.shade700,
          color: Colors.amber.shade700,
          child: _chip(
            emoji: '👑',
            text: 'Deniz Reisi',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            borderColor: Colors.amber.shade700,
            backgroundColor: Colors.amber.withValues(alpha: 0.18),
            textColor: Colors.amber.shade800,
          ),
        );
    }
  }

  Widget _chip({
    required String emoji,
    required String text,
    required double padV,
    required double padH,
    required double fontSize,
    required double iconSize,
    required Color borderColor,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: iconSize),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DenizReisiShimmerBadge extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _DenizReisiShimmerBadge({
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            child,
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Transform.translate(
                offset: Offset((t - 0.5) * 70, 0),
                child: Container(
                  width: 90,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgeConfig {
  final Color background;
  final Color border;
  final Color color;
  final Widget child;

  const _BadgeConfig({
    required this.background,
    required this.border,
    required this.color,
    required this.child,
  });
}

