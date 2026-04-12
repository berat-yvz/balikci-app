import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/moon_phase_calculator.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

/// Günlük balık tahmini — [BalikcimScreen] TabBarView içine gömülür; Scaffold yok.
class DailyForecastScreen extends ConsumerWidget {
  const DailyForecastScreen({super.key});

  static Color _arcColorForLabel(String labelColor) {
    switch (labelColor) {
      case 'green':
        return AppColors.success;
      case 'teal':
        return AppColors.teal;
      case 'amber':
        return AppColors.warning;
      case 'orange':
        return AppColors.accent;
      case 'red':
        return AppColors.danger;
      default:
        return AppColors.foam;
    }
  }

  static String _pressureTrendText(String? trend) {
    switch (trend) {
      case 'rising_fast':
        return '(hızla yükseliyor)';
      case 'rising':
        return '(yükseliyor)';
      case 'stable':
        return '(sabit)';
      case 'falling':
        return '(düşüyor)';
      case 'falling_fast':
        return '(hızla düşüyor)';
      default:
        return '';
    }
  }

  static IconData _pressureTrendIcon(String? trend) {
    switch (trend) {
      case 'rising_fast':
      case 'rising':
        return Icons.trending_up;
      case 'falling_fast':
      case 'falling':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  static Color _pressureTrendIconColor(String? trend) {
    switch (trend) {
      case 'rising_fast':
      case 'rising':
        return AppColors.success;
      case 'falling_fast':
      case 'falling':
        return AppColors.danger;
      default:
        return Colors.white70;
    }
  }

  static String _moonEmoji(double illumination) {
    if (illumination < 0.1) return '🌑';
    if (illumination < 0.25) return '🌒';
    if (illumination < 0.5) return '🌓';
    if (illumination < 0.75) return '🌔';
    if (illumination < 0.9) return '🌕';
    return '🌕';
  }

  static String _moonFishingHint(double illumination) {
    if (illumination > 0.8) {
      return 'Dolunay: Gece avı için ideal 🌕';
    }
    if (illumination < 0.15) {
      return 'Yeni ay: Sığ sularda aktiflik artar';
    }
    return 'Orta ay: Normal koşullar';
  }

  static String _formatIstanbulClock(DateTime utc) {
    final tr = utc.toUtc().add(const Duration(hours: 3));
    final h = tr.hour.toString().padLeft(2, '0');
    final m = tr.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(fishingScoreProvider);
    final weatherAsync = ref.watch(istanbulWeatherProvider);

    final loading = scoreAsync.isLoading || weatherAsync.isLoading;
    if (loading) {
      return ColoredBox(
        color: AppColors.leaderboardBanner,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (scoreAsync.hasError || weatherAsync.hasError) {
      final msg = scoreAsync.hasError
          ? scoreAsync.error.toString()
          : weatherAsync.error.toString();
      return ColoredBox(
        color: AppColors.leaderboardBanner,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tahmin yüklenemedi',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(istanbulWeatherProvider);
                    ref.invalidate(fishingScoreEngineProvider);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final score = scoreAsync.valueOrNull;
    final pack = weatherAsync.valueOrNull;
    if (score == null || pack == null) {
      return ColoredBox(
        color: AppColors.leaderboardBanner,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final weather = pack.current;
    final now = DateTime.now();
    final illum = MoonPhaseCalculator.getMoonIllumination(now);
    final moonName = MoonPhaseCalculator.getMoonPhaseName(illum);

    List<SolunarPeriod> solunar;
    try {
      solunar = MoonPhaseCalculator.getSolunarPeriods(now);
    } catch (_) {
      solunar = const [];
    }

    return ColoredBox(
      color: AppColors.leaderboardBanner,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScoreCard(
              score: score,
              arcColor: _arcColorForLabel(score.labelColor),
              lastUpdateLabel:
                  'Son güncelleme: ${now.hour.toString().padLeft(2, '0')}:00',
            ),
            _BestHoursSection(
              periods: solunar,
              formatTime: _formatIstanbulClock,
            ),
            if (score.activeMessages.isNotEmpty)
              _ActiveMessagesSection(messages: score.activeMessages),
            if (score.suggestedSpecies.isNotEmpty)
              _SuggestedSpeciesSection(species: score.suggestedSpecies),
            _WeatherSummarySection(
              weather: weather,
              trendText: _pressureTrendText(score.pressureTrend),
              trendIcon: _pressureTrendIcon(score.pressureTrend),
              trendIconColor: _pressureTrendIconColor(score.pressureTrend),
            ),
            _MoonPhaseSection(
              emoji: _moonEmoji(illum),
              phaseName: moonName,
              illumination: illum,
              fishingHint: _moonFishingHint(illum),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final FishingScore score;
  final Color arcColor;
  final String lastUpdateLabel;

  const _ScoreCard({
    required this.score,
    required this.arcColor,
    required this.lastUpdateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.scoreGradientDeep,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün Balık Çıkar mı?',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score.label,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      score.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _CircularScore(score: score.score, arcColor: arcColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            lastUpdateLabel,
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularScore extends StatelessWidget {
  final int score;
  final Color arcColor;

  const _CircularScore({required this.score, required this.arcColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: (score.clamp(0, 100)) / 100.0,
          arcColor: arcColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '/100',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.progress, required this.arcColor});

  final double progress;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 4;
    const stroke = 4.0;

    final bgPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.arcColor != arcColor;
  }
}

class _BestHoursSection extends StatelessWidget {
  final List<SolunarPeriod> periods;
  final String Function(DateTime utc) formatTime;

  const _BestHoursSection({
    required this.periods,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⏰ En İyi Saatler',
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (periods.isEmpty)
            Text(
              'Bugün özel solunar pencere yok',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            )
          else
            ...List.generate(periods.length, (i) {
              final p = periods[i];
              final major = p.isMajor;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i > 0)
                    const Divider(color: Colors.white12, height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: major ? AppColors.accent : AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              major ? '🌟 Ana Pencere' : '✦ Yardımcı Pencere',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${formatTime(p.start)} – ${formatTime(p.end)}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _ActiveMessagesSection extends StatelessWidget {
  final List<String> messages;

  const _ActiveMessagesSection({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ Dikkat Edilecekler',
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ...messages.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SuggestedSpeciesSection extends StatelessWidget {
  final List<FishSpeciesTip> species;

  const _SuggestedSpeciesSection({required this.species});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🐟 Bugün Avlanabilir',
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: species.map((s) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.name,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WeatherSummarySection extends StatelessWidget {
  final WeatherModel weather;
  final String trendText;
  final IconData trendIcon;
  final Color trendIconColor;

  const _WeatherSummarySection({
    required this.weather,
    required this.trendText,
    required this.trendIcon,
    required this.trendIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final wave = weather.waveHeight;
    final sea = weather.seaSurfaceTemperature;
    final waveStr =
        wave != null ? '${wave.toStringAsFixed(1)} m' : '—';
    final seaStr =
        sea != null ? '${sea.toStringAsFixed(1)} °C' : '—';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🌊 Hava & Deniz Durumu',
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _WeatherTile(
                value: '${weather.windKmh.round()} km/h',
                label: 'Rüzgâr',
              ),
              _WeatherTile(
                value: '${weather.tempCelsius.toStringAsFixed(0)} °C',
                label: 'Sıcaklık',
              ),
              _WeatherTile(
                value: waveStr,
                label: 'Dalga yüksekliği',
              ),
              _WeatherTile(
                value: seaStr,
                label: 'Deniz sıcaklığı',
              ),
            ],
          ),
          if (weather.pressureHpa != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(trendIcon, color: trendIconColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Basınç: ${weather.pressureHpa!.round()} hPa $trendText',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherTile extends StatelessWidget {
  final String value;
  final String label;

  const _WeatherTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _MoonPhaseSection extends StatelessWidget {
  final String emoji;
  final String phaseName;
  final double illumination;
  final String fishingHint;

  const _MoonPhaseSection({
    required this.emoji,
    required this.phaseName,
    required this.illumination,
    required this.fishingHint,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (illumination * 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: AppTextStyles.h1.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phaseName,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Aydınlanma: %$pct',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fishingHint,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.accent,
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
