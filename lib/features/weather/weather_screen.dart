import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/core/utils/moon_phase_utils.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

/// Detaylı hava durumu ekranı — H9 sprint.
/// Veri yalnızca sunucu `weather_cache` üzerinden gelir; manuel yenileme yoktur.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  static List<HourlyWeatherModel> _next24Hours(
    List<HourlyWeatherModel> source,
  ) {
    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final filtered = source
        .where((h) => !h.time.isBefore(currentHour))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return filtered.length > 24 ? filtered.take(24).toList() : filtered;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Hava Durumu'),
      ),
      body: weatherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const _EmptyWeather(),
        data: (data) {
          final hoursFromNow = _next24Hours(data.hourly);
          final currentHour =
              hoursFromNow.isNotEmpty ? hoursFromNow.first : null;
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_city,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'İstanbul kıyı özeti',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _WeatherHeroCard(weather: data.current),
                const SizedBox(height: 10),
                _FishingScoreCard(weather: data.current, compact: true),
                const SizedBox(height: 12),
                _WeatherDetailGrid(
                  weather: data.current,
                  currentHour: currentHour,
                ),
                const SizedBox(height: 12),

                // ADIM 4: Saatlik tahmin yatay kaydırmalı
                if (hoursFromNow.isNotEmpty) ...[
                  Text(
                    'Saatlik Tahmin',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HourlyScrollRow(hours: hoursFromNow),
                  const SizedBox(height: 12),
                  Text(
                    'Sıcaklık grafiği',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Önümüzdeki 24 saat',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HourlyWeatherChart(hours: hoursFromNow),
                  const SizedBox(height: 12),
                ],

                // Ay fazı kartı — büyük ikon + Türkçe isim
                const _MoonPhaseCard(),
                const SizedBox(height: 12),

              ],
            );
        },
      ),
    );
  }
}

// ── Bugün balık tutulur mu? — kural tabanlı motor ───────────────────────────

Color _fishingAccentFromLabelColor(String labelColor) {
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
      return AppColors.secondary;
  }
}

class _FishingScoreCard extends ConsumerWidget {
  final WeatherModel weather;
  final bool compact;
  const _FishingScoreCard({required this.weather, this.compact = false});

  Color _cardBackground(Color accent) {
    return accent.withValues(alpha: 0.12);
  }

  Widget _messageRow(String text) {
    final isWarn = text.startsWith('⚠️');
    final isOk = text.startsWith('✓');
    final icon = isWarn ? '⚠️' : (isOk ? '✓' : 'ℹ️');
    final body = text.replaceFirst(RegExp(r'^[✓⚠️ℹ️]+\s*'), '').trim();
    final iconColor = isWarn
        ? AppColors.accent
        : (isOk ? AppColors.success : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: compact ? 13 : 14, color: iconColor)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              body.isEmpty ? text : body,
              style: AppTextStyles.caption.copyWith(
                fontSize: compact ? 12 : 14,
                color: Colors.white70,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speciesChips(BuildContext context, List<FishSpeciesTip> species) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: species.map((s) {
        final seasonColor = s.isInSeason ? AppColors.success : AppColors.muted;
        return ActionChip(
          label: Text(
            s.isInSeason ? '${s.name} ✓' : s.name,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: s.isInSeason ? AppColors.success : AppColors.muted,
              fontSize: 12,
            ),
          ),
          backgroundColor: seasonColor.withValues(alpha: 0.12),
          side: BorderSide(color: seasonColor.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onPressed: () {
            final tip = s.tip;
            final msg = tip != null && tip.isNotEmpty
                ? '${s.name} için ipucu: $tip'
                : '${s.name} için ipucu henüz eklenmedi.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScore = ref.watch(fishingScoreProvider);

    return asyncScore.when(
      loading: () => _loadingShell(compact),
      error: (Object e, StackTrace stackTrace) =>
          _legacyCard(context, weather, compact),
      data: (fs) {
        final accent = _fishingAccentFromLabelColor(fs.labelColor);
        final bg = _cardBackground(accent);
        final messages = fs.activeMessages.take(2).toList();

        if (compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bugün balık tutulur mu?',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              fs.label,
                              style: AppTextStyles.caption.copyWith(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (messages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...messages.map(_messageRow),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              fs.summary,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${fs.score}',
                          style: AppTextStyles.h1.copyWith(
                            color: accent,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            '/100',
                            style: AppTextStyles.caption.copyWith(
                              color: accent.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (fs.suggestedSpecies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _speciesChips(context, fs.suggestedSpecies),
                ],
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Bugün balık tutulur mu?',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fs.score}',
                    style: AppTextStyles.h1.copyWith(
                      color: accent,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/100',
                      style: AppTextStyles.h3.copyWith(
                        color: accent.withValues(alpha: 0.7),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fs.label,
                  style: AppTextStyles.h3.copyWith(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...messages.map(_messageRow),
              if (messages.isEmpty)
                Text(
                  fs.summary,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (fs.suggestedSpecies.isNotEmpty) ...[
                const SizedBox(height: 14),
                _speciesChips(context, fs.suggestedSpecies),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _loadingShell(bool compact) {
    final accent = AppColors.secondary;
    final bg = _cardBackground(accent);
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Bugün balık tutulur mu?',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _legacyCard(BuildContext context, WeatherModel w, bool compact) {
    final score = FishingWeatherUtils.getFishingScore(w);
    final accent = score >= 70
        ? AppColors.success
        : (score >= 40 ? AppColors.secondary : AppColors.danger);
    final bg = _cardBackground(accent);
    final label = score >= 70 ? 'İyi' : (score >= 40 ? 'Orta' : 'Kötü');
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugün balık tutulur mu?',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Skor yüklenemedi; basit tahmin gösteriliyor.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$score',
              style: AppTextStyles.h1.copyWith(
                color: accent,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '  $label',
              style: AppTextStyles.caption.copyWith(color: accent),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Skor yüklenemedi ($label · $score)',
        style: AppTextStyles.body.copyWith(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── ADIM 4: Saatlik kartlar — yatay kaydırmalı Row ───────────────────────────

class _HourlyScrollRow extends StatelessWidget {
  final List<HourlyWeatherModel> hours;
  const _HourlyScrollRow({required this.hours});

  String _weatherEmoji(int? code) {
    if (code == null) return '🌤️';
    if (code == 800) return '☀️';
    if (code > 800) return '⛅';
    if (code >= 700) return '🌫️';
    if (code >= 600) return '❄️';
    if (code >= 500) return '🌧️';
    if (code >= 300) return '🌦️';
    if (code >= 200) return '⛈️';
    return '🌤️';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: hours.map((h) {
          final isNow =
              h.time.difference(DateTime.now()).abs().inMinutes <= 30;
          return Container(
            width: 72,
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isNow
                  ? AppColors.primary.withValues(alpha: 0.20)
                  : const Color(0xFF132236),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isNow
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.white10,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${h.time.hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isNow ? AppColors.primary : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weatherEmoji(h.weatherCode),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  '${h.temperature.round()}°',
                  style: TextStyle(
                    color: isNow ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight:
                        isNow ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '💨${h.windspeed.round()}',
                  style: const TextStyle(
                    color: Color(0xFF88BBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Alt widget'lar ──────────────────────────────────────────

class _HourlyWeatherChart extends StatelessWidget {
  final List<HourlyWeatherModel> hours;
  const _HourlyWeatherChart({required this.hours});

  // Her saat sütununun genişliği — 45+ kullanıcı için geniş tutuyoruz.
  static const double _colW = 76.0;
  static const double _chartH = 160.0;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return Text(
        'Saatlik veri şu an için yok',
        style: AppTextStyles.caption.copyWith(color: Colors.white70),
      );
    }

    final minTemp =
        hours.map((h) => h.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp =
        hours.map((h) => h.temperature).reduce((a, b) => a > b ? a : b);
    final totalW = (hours.length * _colW).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F47),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Min/Max özet çipleri ─────────────────────
          Row(
            children: [
              _chip('En düşük  ${minTemp.round()}°C', const Color(0xFF4CB2FF)),
              const SizedBox(width: 8),
              _chip('En yüksek  ${maxTemp.round()}°C', const Color(0xFFFFA63D)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Yatay kaydırmalı grafik + etiketler ──────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Çizgi grafik alanı
                  SizedBox(
                    width: totalW,
                    height: _chartH,
                    child: CustomPaint(
                      size: Size(totalW, _chartH),
                      painter: _LineChartPainter(
                        hours: hours,
                        minTemp: minTemp,
                        maxTemp: maxTemp,
                        colW: _colW,
                        chartH: _chartH,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Saat + rüzgar etiketi ─────────────
                  Row(
                    children: [
                      for (int i = 0; i < hours.length; i++)
                        SizedBox(
                          width: _colW,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${hours[i].time.hour.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: i == 0
                                      ? Colors.white
                                      : Colors.white60,
                                  fontSize: 14,
                                  fontWeight: i == 0
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '💨 ${hours[i].windspeed.round()} km/s',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF88BBFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<HourlyWeatherModel> hours;
  final double minTemp;
  final double maxTemp;
  final double colW;
  final double chartH;

  const _LineChartPainter({
    required this.hours,
    required this.minTemp,
    required this.maxTemp,
    required this.colW,
    required this.chartH,
  });

  // Sıcaklık değerini Y koordinatına dönüştür.
  // topPad: sıcaklık etiketi + emoji için bırakılan boşluk.
  static const double _topPad = 52.0;
  static const double _botPad = 10.0;

  List<Offset> _calcPoints(Size size) {
    final drawH = size.height - _topPad - _botPad;
    final tempRange =
        (maxTemp - minTemp).abs() < 0.5 ? 1.0 : (maxTemp - minTemp);
    return [
      for (int i = 0; i < hours.length; i++)
        Offset(
          colW * i + colW / 2,
          _topPad +
              drawH *
                  (1.0 -
                      ((hours[i].temperature - minTemp) / tempRange)
                          .clamp(0.0, 1.0)),
        ),
    ];
  }

  // Noktalar arasında yumuşak kübik bezier yolu oluşturur.
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
        midX, pts[i].dy,
        midX, pts[i + 1].dy,
        pts[i + 1].dx, pts[i + 1].dy,
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    final pts = _calcPoints(size);
    final drawH = size.height - _topPad - _botPad;

    // ── Yatay grid çizgileri ──────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = _topPad + drawH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Gradyan dolgu (çizginin altı) ────────────────
    final fillPath = _smoothPath(pts)
      ..lineTo(pts.last.dx, _topPad + drawH)
      ..lineTo(pts.first.dx, _topPad + drawH)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4CB2FF).withValues(alpha: 0.38),
            const Color(0xFF4CB2FF).withValues(alpha: 0.02),
          ],
        ).createShader(
          Rect.fromLTWH(0, _topPad, size.width, drawH),
        )
        ..style = PaintingStyle.fill,
    );

    // ── Çizgi ────────────────────────────────────────
    canvas.drawPath(
      _smoothPath(pts),
      Paint()
        ..color = const Color(0xFF4CB2FF)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Her nokta: halka + sıcaklık etiketi ──────────
    for (int i = 0; i < pts.length; i++) {
      final isNow = i == 0;
      final dotR = isNow ? 6.5 : 5.0;

      // Dış beyaz halka
      canvas.drawCircle(
        pts[i],
        dotR + 2,
        Paint()..color = const Color(0xFF1A2F47),
      );
      // Renkli nokta
      canvas.drawCircle(
        pts[i],
        dotR,
        Paint()..color = isNow ? Colors.white : const Color(0xFF4CB2FF),
      );

      // Sıcaklık etiketi (noktanın üstünde)
      final tempSpan = TextSpan(
        text: '${hours[i].temperature.round()}°',
        style: TextStyle(
          color: isNow ? Colors.white : Colors.white70,
          fontSize: isNow ? 18 : 15,
          fontWeight: FontWeight.w800,
        ),
      );
      final tempPainter = TextPainter(
        text: tempSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tempPainter.paint(
        canvas,
        Offset(
          pts[i].dx - tempPainter.width / 2,
          pts[i].dy - dotR - tempPainter.height - 6,
        ),
      );

      // Hava emojisi (etiketin üstünde)
      final emojiSpan = TextSpan(
        text: hours[i].weatherEmoji,
        style: const TextStyle(fontSize: 20),
      );
      final emojiPainter = TextPainter(
        text: emojiSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      emojiPainter.paint(
        canvas,
        Offset(
          pts[i].dx - emojiPainter.width / 2,
          pts[i].dy - dotR - tempPainter.height - emojiPainter.height - 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.hours != hours ||
      old.minTemp != minTemp ||
      old.maxTemp != maxTemp;
}

class _WeatherHeroCard extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherHeroCard({required this.weather});

  String _weatherIcon(int code) {
    if (code == 800) return '☀️';
    if (code > 800) return '⛅';
    if (code >= 700) return '🌫️';
    if (code >= 600) return '❄️';
    if (code >= 500) return '🌧️';
    if (code >= 300) return '🌦️';
    if (code >= 200) return '⛈️';
    return '🌤️';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _weatherIcon(weather.weatherCode ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Text(
            '${weather.tempCelsius.round()}°C',
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetailGrid extends StatelessWidget {
  final WeatherModel weather;
  final HourlyWeatherModel? currentHour;

  const _WeatherDetailGrid({
    required this.weather,
    this.currentHour,
  });

  String _visibilityLabel() {
    final km = weather.visibilityKm ?? currentHour?.visibilityKm;
    if (km == null) return 'Veri yok';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.45,
      children: [
        _DetailTile(
          icon: '💨',
          label: 'Rüzgar',
          value: '${weather.windKmh.toStringAsFixed(0)} km/s',
        ),
        _DetailTile(
          icon: '🌡️',
          label: 'Sıcaklık',
          value: '${weather.tempCelsius.round()}°C',
        ),
        // Dalga yüksekliği — saatlik tahmin verisinden
        if (currentHour?.waveHeight != null)
          _DetailTile(
            icon: '🌊',
            label: 'Dalga',
            value: '${currentHour!.waveHeight!.toStringAsFixed(1)} m',
          ),
        _DetailTile(
          icon: '💧',
          label: 'Nem',
          value: weather.humidity != null
              ? '%${weather.humidity!.toStringAsFixed(0)}'
              : 'Veri yok',
        ),
        _DetailTile(
          icon: '👁️',
          label: 'Görüş',
          value: _visibilityLabel(),
        ),
        _DetailTile(
          icon: '☁️',
          label: 'Bulutluluk',
          value: currentHour?.cloudCover != null
              ? '%${currentHour!.cloudCover!.toStringAsFixed(0)}'
              : weather.cloudCover != null
                  ? '%${weather.cloudCover!.toStringAsFixed(0)}'
                  : 'Veri yok',
        ),
        // Deniz yüzey sıcaklığı — saatlik tahmin verisinden
        if (currentHour?.seaSurfaceTemperature != null)
          _DetailTile(
            icon: '🌡',
            label: 'Deniz Sıcaklığı',
            value:
                '${currentHour!.seaSurfaceTemperature!.round()}°C',
          ),
        // Akıntı hızı ve yönü — saatlik tahmin verisinden
        if (currentHour?.currentVelocity != null)
          _DetailTile(
            icon: currentHour!.currentDirectionArrow ?? '→',
            label: 'Akıntı',
            value: '${(currentHour!.currentVelocity! * 100).round()} cm/s',
          ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String icon, label, value;
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ADIM 4: Ay fazı kartı — büyük ikon + Türkçe faz adı.
class _MoonPhaseCard extends StatelessWidget {
  const _MoonPhaseCard();

  @override
  Widget build(BuildContext context) {
    final moon = MoonPhaseUtils.calculate();
    final pct = (moon.illumination * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F47),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Büyük ay ikonu
          Text(moon.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 10),
          // Faz adı Türkçe
          Text(
            moon.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '%$pct aydınlık',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: moon.illumination,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFF176),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            moon.fishingTip,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyWeather extends StatelessWidget {
  const _EmptyWeather();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Hava verisi bulunamadı',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Hava durumu yüklenemedi.\n'
              'Lütfen internet bağlantınızı kontrol edin.\n'
              'Veri saat başında otomatik güncellenir.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
