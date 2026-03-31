import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

/// Mera marker — CustomPaint teardrop + fish icon.
class SpotMarker extends StatefulWidget {
  final String privacyLevel;
  final int activeCheckinCount;
  final bool hasStaleCheckins;
  final double zoom;

  const SpotMarker({
    super.key,
    required this.privacyLevel,
    this.activeCheckinCount = 0,
    this.hasStaleCheckins = false,
    this.zoom = 10,
  });

  @override
  State<SpotMarker> createState() => _SpotMarkerState();
}

class _SpotMarkerState extends State<SpotMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _a = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    if (widget.activeCheckinCount > 0) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant SpotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeCheckinCount > 0 && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (widget.activeCheckinCount <= 0 && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _resolveColor() {
    switch (widget.privacyLevel) {
      case 'friends':
        return AppColors.pinFriends;
      case 'private':
        return AppColors.pinPrivate;
      case 'vip':
        return AppColors.pinVip;
      case 'public':
      default:
        return AppColors.pinPublic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _resolveColor();
    final isVip = widget.privacyLevel == 'vip';
    final stale = widget.hasStaleCheckins;
    final active = widget.activeCheckinCount > 0;

    final scale = widget.zoom > 13 ? 1.12 : 1.0;
    final opacity = stale ? 0.40 : 1.0;

    Widget marker = Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 56,
        height: 56,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final t = _a.value;
            return CustomPaint(
              painter: _TeardropMarkerPainter(
                color: baseColor,
                pulseT: active ? t : 0,
                showPulse: active,
                vipGlow: isVip,
                stale: stale,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🐟',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.98),
                        ),
                      ),
                      if (isVip) ...[
                        const SizedBox(width: 2),
                        const Text(
                          '⭐',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    marker = Opacity(opacity: opacity, child: marker);
    if (stale) {
      marker = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: marker,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        marker,
        if (widget.activeCheckinCount > 0)
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: baseColor.withValues(alpha: 0.85),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Text(
                widget.activeCheckinCount > 99
                    ? '99+'
                    : widget.activeCheckinCount.toString(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TeardropMarkerPainter extends CustomPainter {
  final Color color;
  final double pulseT; // 0..1
  final bool showPulse;
  final bool vipGlow;
  final bool stale;

  const _TeardropMarkerPainter({
    required this.color,
    required this.pulseT,
    required this.showPulse,
    required this.vipGlow,
    required this.stale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    if (vipGlow) {
      final glow = Paint()
        ..color = AppColors.pinVip.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center.translate(0, -4), 18, glow);
    }

    if (showPulse) {
      final r = 16 + 10 * pulseT;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: (1 - pulseT) * 0.55);
      canvas.drawCircle(center.translate(0, -6), r, ring);
    }

    // Teardrop path
    final body = Path();
    final top = Offset(w / 2, h * 0.16);
    final bottom = Offset(w / 2, h * 0.92);

    body.moveTo(top.dx, top.dy);
    body.cubicTo(
      w * 0.92,
      h * 0.18,
      w * 0.96,
      h * 0.62,
      bottom.dx,
      bottom.dy,
    );
    body.cubicTo(
      w * 0.04,
      h * 0.62,
      w * 0.08,
      h * 0.18,
      top.dx,
      top.dy,
    );
    body.close();

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(body.shift(const Offset(0, 2)), shadow);

    final fill = Paint()
      ..color = color.withValues(alpha: stale ? 0.70 : 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(body, fill);

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(body, stroke);

    // Inner circle to hold icon
    final inner = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(0, -7), 14, inner);

    // Tiny highlight
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(-6, -16), 4, highlight);

    // Optional subtle "fish scale" arcs
    final scalePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final arcRect = Rect.fromCircle(center: center.translate(0, 2), radius: 12);
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        arcRect.inflate(i.toDouble() * 1.2),
        math.pi * 1.05,
        math.pi * 0.35,
        false,
        scalePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeardropMarkerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.pulseT != pulseT ||
        oldDelegate.showPulse != showPulse ||
        oldDelegate.vipGlow != vipGlow ||
        oldDelegate.stale != stale;
  }
}
