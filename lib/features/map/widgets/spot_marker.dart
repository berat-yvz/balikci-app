import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Yaş durumu — check-in'in ne zaman yapıldığına göre belirlenir.
// ──────────────────────────────────────────────────────────────────────────────

enum _AgeState { none, fresh, aging, stale }

_AgeState _calcAgeState(int? ageMinutes) {
  if (ageMinutes == null) return _AgeState.none;
  if (ageMinutes <= 120) return _AgeState.fresh;
  if (ageMinutes <= 300) return _AgeState.aging;
  return _AgeState.stale;
}

/// 0..1 → marker'ın global saydamlığı.
/// fresh=1.0, 300 dk → 0.38, daha sonra sabit kalır.
double _calcOpacity(int? ageMinutes) {
  if (ageMinutes == null) return 0.85;
  if (ageMinutes <= 120) return 1.0;
  if (ageMinutes >= 300) return 0.38;
  return lerpDouble(1.0, 0.38, (ageMinutes - 120) / 180)!;
}

/// Teardrop'un ana rengini zaman geçtikçe amber'a, sonra gri'ye çeker.
Color _tintColor(Color base, int? ageMinutes) {
  if (ageMinutes == null || ageMinutes <= 120) return base;
  const amber = Color(0xFFF5A623);
  const grey = Color(0xFF8EA0B5);
  if (ageMinutes <= 300) {
    final t = (ageMinutes - 120) / 180; // 0..1
    return Color.lerp(base, amber, t * 0.65)!;
  }
  final t = ((ageMinutes - 300) / 120).clamp(0.0, 1.0);
  return Color.lerp(amber, grey, t)!;
}

// ──────────────────────────────────────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────────────────────────────────────

/// Mera harita işareti — yeniden tasarım (45+ kullanıcı dostu).
///
/// [checkinAgeMinutes] : en son check-in'den bu yana geçen süre (dakika).
///   null → hiç check-in yok.
/// [spotName]          : zoom > 13'te marker'ın altında etiket olarak gösterilir.
class SpotMarker extends StatefulWidget {
  final String privacyLevel;
  final int activeCheckinCount;
  final int? checkinAgeMinutes;
  final double zoom;
  final String spotName;

  const SpotMarker({
    super.key,
    required this.privacyLevel,
    this.activeCheckinCount = 0,
    this.checkinAgeMinutes,
    this.zoom = 10,
    this.spotName = '',
  });

  @override
  State<SpotMarker> createState() => _SpotMarkerState();
}

class _SpotMarkerState extends State<SpotMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration());
    _a = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    _startOrStopPulse();
  }

  Duration _pulseDuration() {
    final state = _calcAgeState(widget.checkinAgeMinutes);
    return switch (state) {
      _AgeState.fresh => const Duration(milliseconds: 950),
      _AgeState.aging => const Duration(milliseconds: 2400),
      _ => const Duration(milliseconds: 1200), // dummy; will be stopped
    };
  }

  void _startOrStopPulse() {
    final state = _calcAgeState(widget.checkinAgeMinutes);
    if (state == _AgeState.fresh || state == _AgeState.aging) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant SpotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState = _calcAgeState(oldWidget.checkinAgeMinutes);
    final newState = _calcAgeState(widget.checkinAgeMinutes);
    if (oldState != newState) {
      _pulse.duration = _pulseDuration();
    }
    _startOrStopPulse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _resolveBaseColor() => switch (widget.privacyLevel) {
    'friends' => AppColors.pinFriends,
    'private' => AppColors.pinPrivate,
    'vip' => AppColors.pinVip,
    _ => AppColors.pinPublic,
  };

  @override
  Widget build(BuildContext context) {
    final ageState = _calcAgeState(widget.checkinAgeMinutes);
    final opacity = _calcOpacity(widget.checkinAgeMinutes);
    final baseColor = _resolveBaseColor();
    final tinted = _tintColor(baseColor, widget.checkinAgeMinutes);
    final isVip = widget.privacyLevel == 'vip';
    final showLabel = widget.zoom > 13 && widget.spotName.isNotEmpty;
    final hasBadge = widget.activeCheckinCount > 0 ||
        ageState == _AgeState.aging ||
        ageState == _AgeState.stale;

    return Opacity(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = _a.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ── Ana teardrop pin ─────────────────────────────────────────
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: _TeardropMarkerPainter(
                    color: tinted,
                    pulseT: t,
                    ageState: ageState,
                    vipGlow: isVip,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🐟', style: TextStyle(fontSize: 22)),
                          if (isVip) ...[
                            const SizedBox(width: 2),
                            const Text('⭐', style: TextStyle(fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Yaş + sayı rozeti (sağ üst) ─────────────────────────────
              if (hasBadge)
                Positioned(
                  right: -10,
                  top: -8,
                  child: _AgeBadge(
                    count: widget.activeCheckinCount,
                    ageState: ageState,
                    ageMinutes: widget.checkinAgeMinutes,
                    showAgeText: widget.zoom > 11,
                  ),
                ),

              // ── İsim etiketi (zoom > 13) ─────────────────────────────────
              if (showLabel)
                Positioned(
                  bottom: -22,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      widget.spotName.length > 14
                          ? '${widget.spotName.substring(0, 13)}…'
                          : widget.spotName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Yaş Rozeti
// ──────────────────────────────────────────────────────────────────────────────

class _AgeBadge extends StatelessWidget {
  final int count;
  final _AgeState ageState;
  final int? ageMinutes;
  final bool showAgeText;

  const _AgeBadge({
    required this.count,
    required this.ageState,
    required this.ageMinutes,
    required this.showAgeText,
  });

  Color get _bgColor => switch (ageState) {
    _AgeState.fresh => AppColors.success,
    _AgeState.aging => const Color(0xFFF5A623),
    _ => AppColors.muted,
  };

  String? get _ageLabel {
    if (!showAgeText || ageMinutes == null) return null;
    final m = ageMinutes!;
    if (m < 60) return '${m}dk';
    return '${(m / 60).round()}sa';
  }

  @override
  Widget build(BuildContext context) {
    final label = _ageLabel;
    final showCount = count > 0;
    if (!showCount && label == null) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 7 : 6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCount)
            Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          if (label != null)
            Text(
              label,
              style: TextStyle(
                fontSize: showCount ? 9 : 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CustomPainter
// ──────────────────────────────────────────────────────────────────────────────

class _TeardropMarkerPainter extends CustomPainter {
  final Color color;
  final double pulseT; // 0..1
  final _AgeState ageState;
  final bool vipGlow;

  const _TeardropMarkerPainter({
    required this.color,
    required this.pulseT,
    required this.ageState,
    required this.vipGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // VIP halo
    if (vipGlow) {
      final glow = Paint()
        ..color = AppColors.pinVip.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center.translate(0, -4), 20, glow);
    }

    // Pulse ring
    if (ageState == _AgeState.fresh || ageState == _AgeState.aging) {
      final isFresh = ageState == _AgeState.fresh;
      final r = 17.0 + 11.0 * pulseT;
      final alpha = isFresh
          ? (1 - pulseT) * 0.65
          : (1 - pulseT) * 0.32;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFresh ? 2.5 : 1.5
        ..color = color.withValues(alpha: alpha);
      canvas.drawCircle(center.translate(0, -6), r, ringPaint);
    }

    // Teardrop shape
    final body = Path();
    final top = Offset(w / 2, h * 0.16);
    final bottom = Offset(w / 2, h * 0.92);
    body.moveTo(top.dx, top.dy);
    body.cubicTo(w * 0.92, h * 0.18, w * 0.96, h * 0.62, bottom.dx, bottom.dy);
    body.cubicTo(w * 0.04, h * 0.62, w * 0.08, h * 0.18, top.dx, top.dy);
    body.close();

    // Drop shadow
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(body.shift(const Offset(0, 2)), shadow);

    // Fill
    final fill = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(body, fill);

    // Edge highlight
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(body, stroke);

    // Inner circle (icon container)
    final inner = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(0, -7), 15, inner);

    // Lens highlight
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(-6, -16), 4, highlight);

    // Subtle scale arcs
    final scalePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final arcRect = Rect.fromCircle(
        center: center.translate(0, 2),
        radius: 12 + i * 1.2,
      );
      canvas.drawArc(arcRect, math.pi * 1.05, math.pi * 0.35, false, scalePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TeardropMarkerPainter old) =>
      old.color != color ||
      old.pulseT != pulseT ||
      old.ageState != ageState ||
      old.vipGlow != vipGlow;
}
