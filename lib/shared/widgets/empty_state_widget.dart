import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

enum EmptyStateContext { mapNoSpots, noNotifications, generic }

/// Boş içerik durumu — offline-first, kompakt ve CTA'lı.
///
/// Not: Eski API (title/subtitle/icon) korunur; ayrıca context-aware named
/// constructor'lar eklendi.
class EmptyStateWidget extends StatefulWidget {
  final EmptyStateContext contextType;

  final String title;
  final String subtitle;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.buttonLabel,
    this.onButtonPressed,
  }) : contextType = EmptyStateContext.generic;

  const EmptyStateWidget.mapNoSpots({
    super.key,
    this.buttonLabel,
    this.onButtonPressed,
  }) : contextType = EmptyStateContext.mapNoSpots,
       title = 'Henüz mera yok',
       subtitle = 'Henüz mera yok, ilk sen ekle!',
       icon = Icons.place_outlined;

  const EmptyStateWidget.noNotifications({
    super.key,
    this.buttonLabel,
    this.onButtonPressed,
  }) : contextType = EmptyStateContext.noNotifications,
       title = 'Henüz bildirim yok',
       subtitle = 'Henüz bildirim yok. Yeni gelişmeler burada görünecek.',
       icon = Icons.notifications_outlined;

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String? get _contextEmoji => switch (widget.contextType) {
    EmptyStateContext.mapNoSpots => '🐟',
    EmptyStateContext.noNotifications => null,
    EmptyStateContext.generic => null,
  };

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final subtitle = widget.subtitle;
    final buttonLabel = widget.buttonLabel;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 120,
                  child: widget.contextType == EmptyStateContext.noNotifications
                      ? const Icon(
                          Icons.notifications_rounded,
                          size: 80,
                          color: AppColors.muted,
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_contextEmoji == null)
                              AnimatedBuilder(
                                animation: _c,
                                builder: (context, _) => CustomPaint(
                                  size: Size.infinite,
                                  painter: _EmptyStatePainter(
                                    t: _c.value,
                                    kind: widget.contextType,
                                  ),
                                ),
                              ),
                            if (_contextEmoji != null)
                              Text(
                                _contextEmoji!,
                                style: const TextStyle(
                                  fontSize: 52,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.foam,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.foam.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (buttonLabel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: widget.onButtonPressed,
                      child: Text(buttonLabel),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        size: 18,
                        color: AppColors.muted.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'İpucu: yukarıdan yenile',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStatePainter extends CustomPainter {
  final double t; // 0..1
  final EmptyStateContext kind;

  _EmptyStatePainter({required this.t, required this.kind});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background wave
    final wavePaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final p = Path()..moveTo(0, h * 0.72);
    final phase = t * 6.28318;
    for (double x = 0; x <= w; x += 10) {
      final y = h * 0.72 + 6 * math.sin((x / w) * 6.28318 + phase);
      p.lineTo(x, y);
    }
    canvas.drawPath(p, wavePaint);

    switch (kind) {
      case EmptyStateContext.mapNoSpots:
        _drawFish(canvas, size);
        _drawTextGlyph(canvas, size, '🐟', x: 0.10, y: 0.18);
        break;
      case EmptyStateContext.noNotifications:
        break;
      case EmptyStateContext.generic:
        _drawGenericBox(canvas, size);
        break;
    }
  }

  void _drawFish(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fishX = w * (0.15 + 0.7 * t);
    final fishY = h * 0.42 + 10 * math.sin(t * 6.28318);
    final fishPaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final body = Path()
      ..moveTo(fishX, fishY)
      ..quadraticBezierTo(fishX + 22, fishY - 10, fishX + 36, fishY)
      ..quadraticBezierTo(fishX + 22, fishY + 10, fishX, fishY)
      ..close()
      ..moveTo(fishX + 36, fishY)
      ..lineTo(fishX + 48, fishY - 8)
      ..lineTo(fishX + 48, fishY + 8)
      ..close();
    canvas.drawPath(body, fishPaint);
  }

  void _drawGenericBox(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.44),
        width: 64,
        height: 44,
      ),
      const Radius.circular(12),
    );
    final paint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(r, paint);
    final stroke = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(r, stroke);
  }

  void _drawTextGlyph(
    Canvas canvas,
    Size size,
    String glyph, {
    required double x,
    required double y,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: 20,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * x, size.height * y));
  }

  @override
  bool shouldRepaint(covariant _EmptyStatePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.kind != kind;
  }
}
