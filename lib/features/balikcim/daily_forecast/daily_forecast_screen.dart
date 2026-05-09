import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

String _stripTipPrefix(String m) {
  var s = m.trim();
  const prefixes = ['⚠️ ', 'ℹ️ ', '✓ ', '✔️ ', '🎣 ', '🐟 '];
  for (final p in prefixes) {
    if (s.startsWith(p)) {
      s = s.substring(p.length).trim();
      break;
    }
  }
  return s;
}

/// Özet ile aynı olan ipuçlarını göstermeyi önler.
List<String> _additionalTips(FishingScore score) {
  final summaryNorm = _stripTipPrefix(score.summary).toLowerCase();
  final out = <String>[];
  for (final m in score.activeMessages) {
    final n = _stripTipPrefix(m).toLowerCase();
    if (n.isEmpty || n == summaryNorm) continue;
    out.add(m);
    if (out.length >= 3) break;
  }
  return out;
}

/// Balıkçım — bugün ve yarın için sade, anlaşılır deniz özeti.
class DailyForecastScreen extends ConsumerWidget {
  const DailyForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(fishingScoreProvider);
    final tomorrowAsync = ref.watch(tomorrowFishingScoreProvider);
    final weatherAsync = ref.watch(istanbulWeatherProvider);
    final tomorrowWeatherAsync = ref.watch(tomorrowAggregatedWeatherProvider);
    final regionKey = ref.watch(selectedWeatherRegionProvider);

    if (todayAsync.isLoading) {
      return const ColoredBox(
        color: AppColors.navy,
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 4,
            ),
          ),
        ),
      );
    }

    if (todayAsync.hasError) {
      return ColoredBox(
        color: AppColors.navy,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.muted,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  'Bağlantı hatası',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.foam,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hava verisi alınamadı. İnterneti kontrol edip tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      ref.invalidate(istanbulWeatherProvider);
                      ref.invalidate(fishingScoreEngineProvider);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.foam,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Tekrar Dene',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foam,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final todayScore = todayAsync.valueOrNull;
    if (todayScore == null) {
      return const ColoredBox(
        color: AppColors.navy,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final todayWeather = weatherAsync.valueOrNull?.current;
    final tomorrowScore = tomorrowAsync.valueOrNull;
    final tomorrowWeather = tomorrowWeatherAsync.valueOrNull;
    final regionName =
        weatherRegionDisplayNames[regionKey] ?? regionKey;

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return ColoredBox(
      color: AppColors.navy,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(istanbulWeatherProvider);
          ref.invalidate(fishingScoreEngineProvider);
          await ref.read(istanbulWeatherProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _ExpertHeader(regionName: regionName),
            const SizedBox(height: 10),
            const _ForecastRegionSelector(),
            const SizedBox(height: 16),
            _DayForecastCard(
              dayLabel: 'BUGÜN',
              date: now,
              score: todayScore,
              weather: todayWeather,
              isToday: true,
            ),
            const SizedBox(height: 16),
            if (tomorrowScore != null)
              _DayForecastCard(
                dayLabel: 'YARIN',
                date: tomorrow,
                score: tomorrowScore,
                weather: tomorrowWeather,
                isToday: false,
              )
            else
              const _TomorrowUnavailableCard(),
          ],
        ),
      ),
    );
  }
}

// ── Expert Header ────────────────────────────────────────────────────────────

class _ExpertHeader extends StatelessWidget {
  final String regionName;
  const _ExpertHeader({required this.regionName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bugün deniz nasıl?',
          style: AppTextStyles.h3.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.foam,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.muted,
              size: 18,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                regionName,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Balıkçı özeti',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Karmaşık tablo yok: çıkmak için uygunluk ve hava tek bakışta.',
          style: AppTextStyles.caption.copyWith(
            fontSize: 13,
            height: 1.35,
            color: AppColors.muted.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

// ── Day Forecast Card ────────────────────────────────────────────────────────

class _DayForecastCard extends StatelessWidget {
  final String dayLabel;
  final DateTime date;
  final FishingScore score;
  final WeatherModel? weather;
  final bool isToday;

  const _DayForecastCard({
    required this.dayLabel,
    required this.date,
    required this.score,
    required this.weather,
    required this.isToday,
  });

  static const _turkishDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const _turkishMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_turkishMonths[d.month - 1]}, ${_turkishDays[d.weekday - 1]}';

  Color _scoreAccent(String labelColor) {
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
        return AppColors.primary;
    }
  }

  ({String text, Color color, IconData icon}) _verdict(int s) {
    if (s >= 75) {
      return (
        text: 'Bugün çıkmak için güzel bir gün.',
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    }
    if (s >= 55) {
      return (
        text: 'Denize çıkmak için uygun.',
        color: AppColors.primary,
        icon: Icons.thumb_up_outlined,
      );
    }
    if (s >= 40) {
      return (
        text: 'Çıkabilirsin; dikkatli ol.',
        color: AppColors.warning,
        icon: Icons.warning_amber_outlined,
      );
    }
    if (s >= 20) {
      return (
        text: 'Şartlar zor; deneyimli olmak iyi olur.',
        color: AppColors.accent,
        icon: Icons.waves,
      );
    }
    return (
      text: 'Bugün çıkmayı önermiyoruz.',
      color: AppColors.danger,
      icon: Icons.cancel_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = _scoreAccent(score.labelColor);
    final vd = _verdict(score.score);
    final extraTips = _additionalTips(score);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.surface,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface.withValues(alpha: 0.4),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text(
                  dayLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: isToday ? AppColors.primary : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDate(date),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ana öneri — önce net cümle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: vd.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: vd.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(vd.icon, color: vd.color, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          vd.text,
                          style: AppTextStyles.body.copyWith(
                            fontSize: isToday ? 18 : 17,
                            fontWeight: FontWeight.w800,
                            color: vd.color,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  score.label,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: isToday ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    color: sc,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (score.score.clamp(0, 100)) / 100.0,
                    minHeight: 8,
                    backgroundColor:
                        AppColors.surface.withValues(alpha: 0.85),
                    color: sc,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Genel skor: ${score.score} üzerinden 100 '
                  '(yüksek = daha uygun)',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.muted,
                  ),
                ),

                if (score.summary.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    score.summary,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.foam.withValues(alpha: 0.82),
                    ),
                  ),
                ],

                if (weather != null) ...[
                  const SizedBox(height: 16),
                  _WeatherPlainWords(weather: weather!),
                ],

                if (score.suggestedSpecies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Bugün öne çıkan balıklar',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: score.suggestedSpecies.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          s.name,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foam,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                if (extraTips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      collapsedIconColor: AppColors.muted,
                      iconColor: AppColors.primary,
                      title: Text(
                        'Birkaç ipucu daha',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foam,
                        ),
                      ),
                      subtitle: Text(
                        'İstersen aç — özetle aynı olanlar gösterilmez',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      children: [
                        const SizedBox(height: 4),
                        ...extraTips.map((m) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.tips_and_updates_outlined,
                                  color: AppColors.warning
                                      .withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    m,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: AppColors.foam
                                          .withValues(alpha: 0.78),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hava ve deniz — düz Türkçe cümleler ──────────────────────────────────────

class _WeatherPlainWords extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherPlainWords({required this.weather});

  @override
  Widget build(BuildContext context) {
    final wind = weather.windKmh.round();
    final windWord = wind < 15
        ? 'sakin sayılır'
        : wind < 28
            ? 'orta — takımını sağlam seç'
            : wind < 40
                ? 'güçlü — dikkatli ol'
                : 'çok güçlü — riskli olabilir';

    final lines = <String>[
      'Rüzgar yaklaşık $wind km/saat; bugün için $windWord.',
    ];

    final wave = weather.waveHeight;
    if (wave != null) {
      final waveHint = wave < 0.6
          ? 'alçak, kıyı için genelde rahat'
          : wave < 1.5
              ? 'orta düzeyde'
              : 'yüksek — güvenliği düşün';
      lines.add(
        'Dalga yaklaşık ${wave.toStringAsFixed(1)} metre ($waveHint).',
      );
    }

    lines.add('Hava yaklaşık ${weather.tempCelsius.round()}°C.');

    final sst = weather.seaSurfaceTemperature;
    if (sst != null) {
      lines.add('Deniz suyu yaklaşık ${sst.round()}°C.');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_queue_outlined,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 8),
              Text(
                'Hava ve deniz (özet)',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                Expanded(
                  child: Text(
                    lines[i],
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.foam.withValues(alpha: 0.88),
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

// ── Bölge Seçici ─────────────────────────────────────────────────────────────

/// Balıkçım özet sekmesindeki yatay kaydırmalı bölge seçici.
/// [selectedWeatherRegionProvider] değişince tüm skor providerları otomatik güncellenir.
class _ForecastRegionSelector extends ConsumerWidget {
  const _ForecastRegionSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedWeatherRegionProvider);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weatherRegionDisplayNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final entry = weatherRegionDisplayNames.entries.elementAt(i);
          final isSelected = entry.key == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(selectedWeatherRegionProvider.notifier).state =
                    entry.key,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.muted.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                entry.value,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: isSelected ? AppColors.foam : AppColors.muted,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tomorrow Unavailable ─────────────────────────────────────────────────────

class _TomorrowUnavailableCard extends StatelessWidget {
  const _TomorrowUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surface),
      ),
      child: Column(
        children: [
          const Icon(Icons.schedule, color: AppColors.muted, size: 44),
          const SizedBox(height: 14),
          Text(
            'Yarınki tahmin mevcut değil',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.foam,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saatlik hava verisi henüz yüklenmedi.\nKısa süre içinde tekrar deneyin.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
