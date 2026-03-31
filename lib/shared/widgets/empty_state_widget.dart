import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

enum EmptyStateContext {
  mapNoSpots,
  noFishLogs,
  noNotifications,
  generic,
}

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
  })  : contextType = EmptyStateContext.mapNoSpots,
        title = 'Henüz mera yok',
        subtitle = 'Henüz mera yok, ilk sen ekle!',
        icon = Icons.place_outlined;

  const EmptyStateWidget.noFishLogs({
    super.key,
    this.buttonLabel,
    this.onButtonPressed,
  })  : contextType = EmptyStateContext.noFishLogs,
        title = 'İlk avını kaydet',
        subtitle = 'İlk avını kaydet! Sonra istatistiklerini burada görürsün.',
        icon = Icons.menu_book_outlined;

  const EmptyStateWidget.noNotifications({
    super.key,
    this.buttonLabel,
    this.onButtonPressed,
  })  : contextType = EmptyStateContext.noNotifications,
        title = 'Henüz bildirim yok',
        subtitle = 'Henüz bildirim yok. Yeni gelişmeler burada görünecek.',
        icon = Icons.notifications_none;

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
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _EmptyStatePainter(
                          t: _c.value,
                          kind: widget.contextType,
                        ),
                      );
                    },
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
                      Icon(widget.icon,
                          size: 18, color: AppColors.muted.withValues(alpha: 0.9)),
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

  _EmptyStatePainter({
    required this.t,
    required this.kind,
  });

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
      case EmptyStateContext.noFishLogs:
        _drawRod(canvas, size);
        break;
      case EmptyStateContext.noNotifications:
        _drawBell(canvas, size);
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

  void _drawRod(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rodPaint = Paint()
      ..color = AppColors.sand.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.25, h * 0.18),
      Offset(w * 0.60, h * 0.58),
      rodPaint,
    );

    final linePaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final x = w * 0.60;
    final y = h * 0.58;
    final hookDrop = 18 + 10 * (0.5 + 0.5 * math.sin(t * 6.28318));
    final line = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + 18, y + 12, x + 10, y + hookDrop);
    canvas.drawPath(line, linePaint);

    final hookPaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x + 10, y + hookDrop + 6), radius: 7),
      math.pi * 1.1,
      math.pi * 1.1,
      false,
      hookPaint,
    );
  }

  void _drawBell(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.50, h * 0.42);

    final bellPaint = Paint()
      ..color = AppColors.foam.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: c.translate(0, -6),
      width: w * 0.26,
      height: h * 0.34,
    );
    canvas.drawArc(rect, math.pi, math.pi, false, bellPaint);
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      bellPaint,
    );

    final ripplePaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.18 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c.translate(0, -10), 22 + 10 * t, ripplePaint);
    canvas.drawCircle(c.translate(0, -10), 30 + 14 * t, ripplePaint);
  }

  void _drawGenericBox(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.44), width: 64, height: 44),
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

  void _drawTextGlyph(Canvas canvas, Size size, String glyph,
      {required double x, required double y}) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.65)),
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
