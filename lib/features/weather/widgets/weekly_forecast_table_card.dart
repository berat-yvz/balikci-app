import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/weekly_forecast_aggregate.dart';

/// Open-Meteo saatlik veriden türetilen haftalık özet tablosu (kıyı ekranı).
class WeeklyForecastTableCard extends StatelessWidget {
  final List<WeeklyForecastRow> rows;

  const WeeklyForecastTableCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RainBackdropPainter()),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A3D44).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '7 günlük özet',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saatlik tahminden hesaplanır',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 10),
                    child: _WeeklyForecastRowWidget(row: rows[i]),
                  ),
                ],
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => context.go(AppRoutes.balikcim),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '15 günlük hava durumu tahmini',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyForecastRowWidget extends StatelessWidget {
  final WeeklyForecastRow row;

  const _WeeklyForecastRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.precipChancePercent;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            row.dayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: pct == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '%$pct',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WeatherGlyph(kind: row.dayVisual, size: 26),
              const SizedBox(width: 10),
              _WeatherGlyph(kind: row.nightVisual, size: 26),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${row.highC}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${row.lowC}°',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherGlyph extends StatelessWidget {
  final WeeklyWeatherVisualKind kind;
  final double size;

  const _WeatherGlyph({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WeatherGlyphPainter(kind)),
    );
  }
}

class _WeatherGlyphPainter extends CustomPainter {
  final WeeklyWeatherVisualKind kind;

  _WeatherGlyphPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (kind) {
      case WeeklyWeatherVisualKind.rain:
        _paintRain(canvas, size);
      case WeeklyWeatherVisualKind.cloudy:
        _paintCloud(canvas, cx, cy, size.width * 0.38, const Color(0xFFE8EEF5));
      case WeeklyWeatherVisualKind.partlyCloudyDay:
        _paintSun(canvas, cx - size.width * 0.12, cy - size.height * 0.1, size.width * 0.22);
        _paintCloud(
          canvas,
          cx + size.width * 0.06,
          cy + size.height * 0.08,
          size.width * 0.30,
          Colors.white,
        );
      case WeeklyWeatherVisualKind.partlyCloudyNight:
        _paintMoon(canvas, cx - size.width * 0.14, cy - size.height * 0.1, size.width * 0.20);
        _paintCloud(
          canvas,
          cx + size.width * 0.06,
          cy + size.height * 0.08,
          size.width * 0.28,
          Colors.white,
        );
      case WeeklyWeatherVisualKind.clearDay:
        _paintSun(canvas, cx, cy, size.width * 0.36);
      case WeeklyWeatherVisualKind.clearNight:
        _paintMoon(canvas, cx, cy, size.width * 0.34);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final ox = size.width * 0.15;
    final oy = size.height * 0.2;
    for (var i = 0; i < 3; i++) {
      final dx = ox + i * size.width * 0.22;
      canvas.drawLine(Offset(dx, oy), Offset(dx + 5, oy + size.height * 0.48), p);
    }
  }

  void _paintSun(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFFFD54F),
    );
  }

  void _paintMoon(Canvas canvas, double cx, double cy, double r) {
    final moonPath = Path()
      ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -math.pi * 0.35, math.pi * 1.7);
    canvas.drawPath(
      moonPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.38
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintCloud(Canvas canvas, double cx, double cy, double w, Color fill) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx - w * 0.35, cy), radius: w * 0.42))
      ..addOval(Rect.fromCircle(center: Offset(cx + w * 0.35, cy), radius: w * 0.48))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy - w * 0.22), radius: w * 0.44));
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(covariant _WeatherGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// İnce çizgiler — ekran görüntüsündeki hafif yağış dokusu.
class _RainBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width + size.height; x += 11) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.35, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
