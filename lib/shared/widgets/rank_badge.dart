import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

enum RankBadgeSize { compact, small, medium, large }

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
    );
    if (widget.rank == 'deniz_reisi' && widget.size != RankBadgeSize.compact) {
      _controller.repeat();
    }
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

    final child = _isDenizReisi && widget.size != RankBadgeSize.compact
        ? _DenizReisiShimmerBadge(controller: _controller, child: cfg.child)
        : cfg.child;

    return child;
  }

  _BadgeConfig _badgeConfig(String rank, RankBadgeSize size) {
    final isCompact = size == RankBadgeSize.compact;
    final isSmall = size == RankBadgeSize.small;
    final isLarge = size == RankBadgeSize.large;

    final double padV = isCompact ? 2 : (isSmall ? 6 : (isLarge ? 12 : 9));
    final double padH = isCompact ? 5 : (isSmall ? 10 : (isLarge ? 14 : 12));
    final double fontSize = isCompact
        ? 10
        : (isSmall ? 13 : (isLarge ? 18 : 15));
    final double iconSize = isCompact
        ? 11
        : (isSmall ? 16 : (isLarge ? 22 : 18));
    final double emojiGap = isCompact ? 3 : 8;

    switch (rank) {
      case 'acemi':
        return _BadgeConfig(
          child: _chip(
            emoji: '🪝',
            text: 'Acemi',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            emojiTextGap: emojiGap,
            compact: isCompact,
            borderColor: Colors.transparent,
            backgroundColor: AppColors.rankAcemi.withValues(alpha: 0.15),
            textColor: AppColors.rankAcemi,
          ),
        );
      case 'olta_kurdu':
        return _BadgeConfig(
          child: _chip(
            emoji: '🎣',
            text: 'Olta Kurdu',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            emojiTextGap: emojiGap,
            compact: isCompact,
            borderColor: Colors.transparent,
            backgroundColor: AppColors.rankOltaKurdu.withValues(alpha: 0.15),
            textColor: AppColors.rankOltaKurdu,
          ),
        );
      case 'usta':
        return _BadgeConfig(
          child: _chip(
            emoji: '⚓',
            text: 'Usta',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            emojiTextGap: emojiGap,
            compact: isCompact,
            borderColor: AppColors.rankUsta,
            backgroundColor: AppColors.rankUsta.withValues(alpha: 0.10),
            textColor: AppColors.rankUsta,
          ),
        );
      case 'deniz_reisi':
      default:
        return _BadgeConfig(
          child: _chip(
            emoji: '👑',
            text: 'Deniz Reisi',
            padV: padV,
            padH: padH,
            fontSize: fontSize,
            iconSize: iconSize,
            emojiTextGap: emojiGap,
            compact: isCompact,
            borderColor: AppColors.rankDenizReisi,
            backgroundColor: AppColors.rankDenizReisi.withValues(alpha: 0.18),
            textColor: AppColors.rankDenizReisi,
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
    required double emojiTextGap,
    required bool compact,
    required Color borderColor,
    required Color backgroundColor,
    required Color textColor,
  }) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );

    return Container(
      constraints: compact ? const BoxConstraints(maxWidth: 112) : null,
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: iconSize)),
          SizedBox(width: emojiTextGap),
          if (compact) Expanded(child: textWidget) else textWidget,
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
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
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
  final Widget child;

  const _BadgeConfig({required this.child});
}
