import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/core/utils/moon_phase_utils.dart';
import 'package:balikci_app/data/models/hourly_weather_model.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/core/utils/weekly_forecast_aggregate.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/features/weather/widgets/weekly_forecast_table_card.dart';
import 'package:balikci_app/core/utils/weather_tr_schedule.dart';
import 'package:balikci_app/shared/widgets/app_filter_chip.dart';

/// Detaylı hava durumu ekranı — H9 sprint.
///
/// Veri `weather_cache` + yerel Drift: sunucu saat başında Edge `weather-cache`
/// ile Open-Meteo doldurur; uygulama **yalnızca her saat :02** (İstanbul)
/// `weather_cache` okur. Aşağı kaydırma Edge tetiklemez, yalnızca Drift yenilenir.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  static List<HourlyWeatherModel> _next24Hours(
    List<HourlyWeatherModel> source,
  ) {
    final nowU = DateTime.now().toUtc();
    final currentHour = startOfCurrentIstanbulWallHourUtc(nowU);
    final filtered = source
        .where((h) => !h.time.toUtc().isBefore(currentHour))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return filtered.length > 24 ? filtered.take(24).toList() : filtered;
  }

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(istanbulWeatherProvider.notifier).pullLatestSilently(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(istanbulWeatherProvider.notifier).pullLatestSilently(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);
    final selectedRegion = ref.watch(selectedWeatherRegionProvider);
    final regionDisplayName =
        weatherRegionDisplayNames[selectedRegion] ?? selectedRegion;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Hava Durumu')),
      body: weatherAsync.when(
        loading: () => const _WeatherLoadingSkeleton(),
        error: (error, stack) => const _EmptyWeather(),
        data: (data) {
          final hoursFromNow = WeatherScreen._next24Hours(data.hourly);
          final currentHour = hoursFromNow.isNotEmpty
              ? hoursFromNow.first
              : null;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await ref
                  .read(istanbulWeatherProvider.notifier)
                  .refreshFromServer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Hava verisi sunucudan güncellendi. Tam taze özet saat başında '
                      'arka planda hesaplanır; uygulama genelde yerel saat ile :02 '
                      'geçe çeker.',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              cacheExtent: 380,
              children: [
                const _RegionSelector(),
                if (data.isFromCache) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_outlined,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Çevrimdışı mod — son önbellekten gösteriliyor. '
                            'Saatlik tahmin mevcut değil.',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$regionDisplayName kıyı özeti',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _WeatherHeroCard(weather: data.current),
                if (data.current.fishingSummary != null &&
                    data.current.fishingSummary!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      data.current.fishingSummary!,
                      style: AppTextStyles.body.copyWith(color: AppColors.foam),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 6),
                _FetchedAtLabel(fetchedAt: data.current.fetchedAt),
                _WeatherDetailGrid(
                  weather: data.current,
                  currentHour: currentHour,
                ),
                const SizedBox(height: 12),

                if (data.hourly.isNotEmpty) ...[
                  RepaintBoundary(
                    child: WeeklyForecastTableCard(
                      rows: buildWeeklyForecastRows(
                        data.hourly,
                        DateTime.now().toUtc(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                  RepaintBoundary(child: _HourlyScrollRow(hours: hoursFromNow)),
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
                  RepaintBoundary(
                    child: _HourlyWeatherChart(hours: hoursFromNow),
                  ),
                  const SizedBox(height: 12),
                ],

                // Ay fazı kartı — büyük ikon + Türkçe isim
                const _MoonPhaseCard(),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// İlk karede tam ekran spinner yerine yer tutucu — veri gelince liste ile değişir.
class _WeatherLoadingSkeleton extends StatelessWidget {
  const _WeatherLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double height) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF132236),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        bar(52),
        bar(152),
        bar(88),
        bar(240),
        bar(112),
      ],
    );
  }
}

// ── Son güncelleme etiketi ────────────────────────────────────────────────────

class _FetchedAtLabel extends StatelessWidget {
  final DateTime fetchedAt;
  const _FetchedAtLabel({required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    final hhmm = DateFormat('HH:mm').format(fetchedAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Son güncelleme: $hhmm',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.muted.withValues(alpha: 0.88),
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Saatlik kartlar — yatay kaydırmalı Row ───────────────────────────────────

class _HourlyScrollRow extends StatelessWidget {
  final List<HourlyWeatherModel> hours;
  const _HourlyScrollRow({required this.hours});

  @override
  Widget build(BuildContext context) {
    final nowU = DateTime.now().toUtc();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: hours.map((h) {
          final isNow =
              h.time.toUtc().difference(nowU).abs().inMinutes <= 30;
          return Container(
            width: 72,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                  '${istanbulWallHourFromUtc(h.time).toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isNow ? AppColors.primary : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(h.weatherEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  '${h.temperature.round()}°',
                  style: TextStyle(
                    color: isNow ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: isNow ? FontWeight.w900 : FontWeight.w600,
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

    final minTemp = hours
        .map((h) => h.temperature)
        .reduce((a, b) => a < b ? a : b);
    final maxTemp = hours
        .map((h) => h.temperature)
        .reduce((a, b) => a > b ? a : b);
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
            primary: false,
            physics: const ClampingScrollPhysics(),
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
                                '${istanbulWallHourFromUtc(hours[i].time).toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: i == 0 ? Colors.white : Colors.white60,
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

  // ── Ön-hesaplanmış sabit Paint nesneleri ────────────────────────────────────
  // paint() çağrısı başına nesne üretmek pahalıdır; bir kez oluştur, tekrar kullan.
  late final Paint _gridPaint;
  late final Paint _linePaint;
  late final Paint _dotBgPaint;
  late final Paint _dotNowPaint;
  late final Paint _dotPaint;

  // ── Ön-hesaplanmış TextPainter listesi ──────────────────────────────────────
  // layout() çok pahalıdır; constructor'da bir kez çalıştırılır.
  late final List<TextPainter> _tempPainters;
  late final List<TextPainter> _emojiPainters;

  // ── Gradient shader cache — size değişirse yeniden oluşturulur ───────────────
  Rect? _cachedFillRect;
  Paint? _cachedFillPaint;

  _LineChartPainter({
    required this.hours,
    required this.minTemp,
    required this.maxTemp,
    required this.colW,
    required this.chartH,
  }) {
    _gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    _linePaint = Paint()
      ..color = const Color(0xFF4CB2FF)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _dotBgPaint = Paint()..color = const Color(0xFF1A2F47);
    _dotNowPaint = Paint()..color = Colors.white;
    _dotPaint = Paint()..color = const Color(0xFF4CB2FF);

    _tempPainters = [
      for (int i = 0; i < hours.length; i++)
        TextPainter(
          text: TextSpan(
            text: '${hours[i].temperature.round()}°',
            style: TextStyle(
              color: i == 0 ? Colors.white : Colors.white70,
              fontSize: i == 0 ? 18 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    _emojiPainters = [
      for (int i = 0; i < hours.length; i++)
        TextPainter(
          text: TextSpan(
            text: hours[i].weatherEmoji,
            style: const TextStyle(fontSize: 20),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
  }

  // Sıcaklık değerini Y koordinatına dönüştür.
  static const double _topPad = 52.0;
  static const double _botPad = 10.0;

  List<Offset> _calcPoints(Size size) {
    final drawH = size.height - _topPad - _botPad;
    final tempRange = (maxTemp - minTemp).abs() < 0.5
        ? 1.0
        : (maxTemp - minTemp);
    return [
      for (int i = 0; i < hours.length; i++)
        Offset(
          colW * i + colW / 2,
          _topPad +
              drawH *
                  (1.0 -
                      ((hours[i].temperature - minTemp) / tempRange).clamp(
                        0.0,
                        1.0,
                      )),
        ),
    ];
  }

  // Noktalar arasında yumuşak kübik bezier yolu oluşturur.
  Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
        midX,
        pts[i].dy,
        midX,
        pts[i + 1].dy,
        pts[i + 1].dx,
        pts[i + 1].dy,
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
    for (int i = 1; i <= 3; i++) {
      final y = _topPad + drawH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // ── Bezier yolu tek seferlik hesapla ────────────
    // fill için kopyasını çıkar (Path.from), stroke için orijinali kullan.
    final strokePath = _smoothPath(pts);
    final fillPath = Path.from(strokePath)
      ..lineTo(pts.last.dx, _topPad + drawH)
      ..lineTo(pts.first.dx, _topPad + drawH)
      ..close();

    // ── Gradient fill Paint — yalnızca size değiştiğinde yeniden oluştur ──────
    final fillRect = Rect.fromLTWH(0, _topPad, size.width, drawH);
    if (_cachedFillRect != fillRect) {
      _cachedFillRect = fillRect;
      _cachedFillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4CB2FF).withValues(alpha: 0.38),
            const Color(0xFF4CB2FF).withValues(alpha: 0.02),
          ],
        ).createShader(fillRect)
        ..style = PaintingStyle.fill;
    }

    canvas.drawPath(fillPath, _cachedFillPaint!);
    canvas.drawPath(strokePath, _linePaint);

    // ── Her nokta: halka + ön-hesaplanmış etiketler ──
    for (int i = 0; i < pts.length; i++) {
      final isNow = i == 0;
      final dotR = isNow ? 6.5 : 5.0;

      canvas.drawCircle(pts[i], dotR + 2, _dotBgPaint);
      canvas.drawCircle(pts[i], dotR, isNow ? _dotNowPaint : _dotPaint);

      final tp = _tempPainters[i];
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, pts[i].dy - dotR - tp.height - 6),
      );

      final ep = _emojiPainters[i];
      ep.paint(
        canvas,
        Offset(
          pts[i].dx - ep.width / 2,
          pts[i].dy - dotR - tp.height - ep.height - 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    if (identical(old.hours, hours) &&
        old.minTemp == minTemp &&
        old.maxTemp == maxTemp) {
      return false;
    }
    if (old.hours.length != hours.length ||
        old.minTemp != minTemp ||
        old.maxTemp != maxTemp) {
      return true;
    }
    for (var i = 0; i < hours.length; i++) {
      final a = old.hours[i];
      final b = hours[i];
      if (a.time != b.time ||
          a.temperature != b.temperature ||
          a.weatherCode != b.weatherCode) {
        return true;
      }
    }
    return false;
  }
}

class _WeatherHeroCard extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherHeroCard({required this.weather});

  // Open-Meteo WMO kodlarına göre emoji (OWM kodları değil).
  String _weatherIcon(int? code) {
    if (code == null) return '🌤️';
    if (code == 0) return '☀️'; // Açık gökyüzü
    if (code <= 3) return '⛅'; // Parçalı bulutlu
    if (code <= 49) return '🌫️'; // Sis / pus
    if (code <= 69) return '🌧️'; // Çisenti / yağmur
    if (code <= 79) return '❄️'; // Kar
    if (code <= 82) return '🌦️'; // Sağanak yağış
    if (code <= 99) return '⛈️'; // Gök gürültülü fırtına
    return '🌤️';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _weatherIcon(weather.weatherCode);

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

  const _WeatherDetailGrid({required this.weather, this.currentHour});

  String _visibilityLabel() {
    final km = weather.visibilityKm ?? currentHour?.visibilityKm;
    if (km == null) return 'Veri yok';
    return '${km.round()} km';
  }

  String _windDirLabel(int? deg) {
    if (deg == null) return '—';
    if (deg >= 30 && deg < 60) return 'Poyraz ↗';
    if (deg >= 60 && deg < 90) return 'Gündoğusu →';
    if (deg >= 180 && deg < 220) return 'Lodos ↙ ⚠️';
    if (deg >= 200 && deg < 230) return 'Kıble ↓ ⚠️';
    if (deg >= 240 && deg < 270) return 'Keşişleme ↙ ⚠️';
    if (deg >= 300 && deg < 330) return 'Karayel ↖';
    if (deg >= 345 || deg < 15) return 'Yıldız ↑';
    return '$deg°';
  }

  /// Lodos bandı (mevcut etiket) veya güney bileşeni güçlü rüzgar (≈165°–195°).
  bool _isLodosOrSouthWind(int? deg) {
    if (deg == null) return false;
    if (deg >= 180 && deg < 220) return true;
    if (deg >= 165 && deg <= 195) return true;
    return false;
  }

  static const Color _lodosChipBg = Color(0xFFFAEEDA);
  static const Color _lodosChipFg = Color(0xFF854F0B);

  Widget _windDirectionValue(int? deg) {
    final normal = _windDirLabel(deg);
    if (!_isLodosOrSouthWind(deg)) {
      return Text(
        normal,
        style: AppTextStyles.caption.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _lodosChipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: _lodosChipFg,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lodos — Av olumsuz etkilenebilir',
              style: TextStyle(
                color: _lodosChipFg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
        // Dalga yüksekliği — saatlik veriden, yoksa WeatherModel alanına düş
        _DetailTile(
          icon: '🌊',
          label: 'Dalga',
          value: () {
            final h = currentHour?.waveHeight ?? weather.waveHeight;
            return h != null ? '${h.toStringAsFixed(1)} m' : 'Veri yok';
          }(),
          valueColor: currentHour?.waveHeight == null ? AppColors.muted : null,
        ),
        _DetailTile(
          icon: '💧',
          label: 'Nem',
          value: weather.humidity != null
              ? '%${weather.humidity!.toStringAsFixed(0)}'
              : 'Veri yok',
        ),
        _DetailTile(icon: '👁️', label: 'Görüş', value: _visibilityLabel()),
        _DetailTile(
          icon: '☁️',
          label: 'Bulutluluk',
          value: currentHour?.cloudCover != null
              ? '%${currentHour!.cloudCover!.toStringAsFixed(0)}'
              : weather.cloudCover != null
              ? '%${weather.cloudCover!.toStringAsFixed(0)}'
              : 'Veri yok',
        ),
        // Deniz yüzey sıcaklığı — saatlik veriden, yoksa WeatherModel alanına düş
        _DetailTile(
          icon: '🌡',
          label: 'Deniz Sıcaklığı',
          value: () {
            final sst =
                currentHour?.seaSurfaceTemperature ??
                weather.seaSurfaceTemperature;
            return sst != null ? '${sst.round()}°C' : 'Veri yok';
          }(),
          valueColor: currentHour?.seaSurfaceTemperature == null
              ? AppColors.muted
              : null,
        ),
        // Akıntı hızı ve yönü — saatlik tahmin verisinden
        _DetailTile(
          icon: currentHour?.currentVelocity != null
              ? (currentHour!.currentDirectionArrow ?? '→')
              : '→',
          label: 'Akıntı',
          value: currentHour?.currentVelocity != null
              ? '${(currentHour!.currentVelocity! * 100).round()} cm/s'
              : 'Veri yok',
          valueColor: currentHour?.currentVelocity == null
              ? AppColors.muted
              : null,
        ),
        _DetailTile(
          icon: '🧭',
          label: 'Rüzgar Yönü',
          value: _windDirLabel(
            currentHour?.windDirection ?? weather.windDirection,
          ),
          valueWidget: _windDirectionValue(
            currentHour?.windDirection ?? weather.windDirection,
          ),
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String icon, label, value;
  final Color? valueColor;
  /// [value] yerine gösterilir (ör. Lodos uyarı chip'i).
  final Widget? valueWidget;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 16,
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                valueWidget ??
                    Text(
                      value,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
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

// ── Bölge seçici chip bar ────────────────────────────────────────────────────

class _RegionSelector extends ConsumerWidget {
  const _RegionSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedWeatherRegionProvider);
    final entries = weatherRegionDisplayNames.entries.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            AppFilterChip(
              label: entry.value,
              isSelected: entry.key == selected,
              onTap: () =>
                  ref.read(selectedWeatherRegionProvider.notifier).state =
                      entry.key,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyWeather extends ConsumerWidget {
  const _EmptyWeather();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(istanbulWeatherProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Yenile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
