import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';

/// Detaylı hava durumu ekranı — H9 sprint.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  @override
  void initState() {
    super.initState();
    // Artık otomatik yükleme provider tarafından yapılıyor
  }

  Future<void> _onRefresh() async {
    await ref.read(istanbulWeatherProvider.notifier).refresh();
  }

  List<HourlyWeatherModel> _hoursFromNow(List<HourlyWeatherModel> source) {
    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final filtered = source.where((h) => !h.time.isBefore(currentHour)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // Önümüzdeki 12 saat, okunabilirlik için yeterli.
    if (filtered.length > 12) return filtered.take(12).toList();
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hava Durumu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Hava durumunu güncelle',
          ),
        ],
      ),
      body: weatherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _EmptyWeather(onRetry: _onRefresh),
        data: (data) => RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'İstanbul',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              if (data.current != null) ...[
                _WeatherHeroCard(weather: data.current!),
                const SizedBox(height: 16),
                _WeatherDetailGrid(weather: data.current!),
                const SizedBox(height: 16),
                _FishingTipsCard(weather: data.current!),
                const SizedBox(height: 16),
                _UpdateInfo(
                  weather: data.current!,
                  lastUpdated: data.lastUpdated,
                ),
                const SizedBox(height: 16),
              ],

              Text(
                'Saatlik Tahmin',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              data.hourly.isEmpty
                  ? Text(
                      'Saatlik hava verisi alınamadı',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    )
                  : _HourlyWeatherChart(hours: _hoursFromNow(data.hourly)),
            ],
          ),
        ),
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

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.primary;
    if (score >= 50) return AppColors.accent;
    if (score >= 25) return const Color(0xFFE07B39);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final score = FishingWeatherUtils.getFishingScore(weather);
    final summary = FishingWeatherUtils.getSummary(weather);
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
            '${weather.tempCelsius.toStringAsFixed(1)}°C',
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: AppTextStyles.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _scoreColor(score).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _scoreColor(score).withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              '${FishingWeatherUtils.getScoreEmoji(score)} '
              'Balıkçılık skoru: $score/100 — '
              '${FishingWeatherUtils.getScoreLabel(score)}',
              style: AppTextStyles.caption.copyWith(
                color: _scoreColor(score),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetailGrid extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherDetailGrid({required this.weather});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _DetailTile(
          icon: '💨',
          label: 'Rüzgar',
          value: '${weather.windKmh.toStringAsFixed(0)} km/s',
        ),
        _DetailTile(
          icon: '🌡️',
          label: 'Sıcaklık',
          value: '${weather.tempCelsius.toStringAsFixed(1)}°C',
        ),
        if (weather.waveHeight != null)
          _DetailTile(
            icon: '🌊',
            label: 'Dalga',
            value: '${weather.waveHeight!.toStringAsFixed(1)} m',
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
          value: weather.visibilityKm != null
              ? '${weather.visibilityKm!.toStringAsFixed(1)} km'
              : 'Veri yok',
        ),
        _DetailTile(
          icon: '☁️',
          label: 'Bulutluluk',
          value: weather.cloudCover != null
              ? '%${weather.cloudCover!.toStringAsFixed(0)}'
              : 'Veri yok',
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
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
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

class _FishingTipsCard extends StatelessWidget {
  final WeatherModel weather;
  const _FishingTipsCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final wind = weather.windKmh;
    final temp = weather.tempCelsius;

    final tips = <String>[];
    if (wind < 15) tips.add('✓ Rüzgar ideal seviyede');
    if (wind > 25) tips.add('⚠️ Rüzgar yüksek, dikkatli ol');
    if (temp >= 16 && temp <= 24) tips.add('✓ Su sıcaklığı balık için ideal');
    if (temp > 28) tips.add('⚠️ Çok sıcak, derin sulara bak');
    if (temp < 10) tips.add('⚠️ Soğuk su, yavaş balıklar');
    if (tips.isEmpty) tips.add('Koşullar ortalama, denemeye değer');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balıkçı Tüyoları',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tip,
                style: AppTextStyles.caption.copyWith(
                  color: tip.startsWith('✓')
                      ? AppColors.primary
                      : tip.startsWith('⚠️')
                      ? AppColors.accent
                      : Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateInfo extends StatelessWidget {
  final WeatherModel weather;
  final DateTime lastUpdated;
  const _UpdateInfo({required this.weather, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final ago = DateTime.now().difference(lastUpdated);
    final label = ago.inMinutes < 60
        ? '${ago.inMinutes} dakika önce güncellendi'
        : '${ago.inHours} saat önce güncellendi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🕐', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWeather extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyWeather({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            'Supabase weather_cache tablosu boş olabilir.\n'
            'Edge Function deploy edildi mi?',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
