import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

/// Balıkçım Uzman Sayfası — bugün ve yarın için balığa gitme kararı.
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
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: AppColors.muted,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          regionName,
          style: AppTextStyles.caption.copyWith(
            fontSize: 14,
            color: AppColors.muted,
          ),
        ),
        const Spacer(),
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
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                'Uzman Analizi',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
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
        text: 'Kesinlikle Gidebilirsin!',
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    }
    if (s >= 55) {
      return (
        text: 'Gidebilirsin',
        color: AppColors.primary,
        icon: Icons.thumb_up_outlined,
      );
    }
    if (s >= 40) {
      return (
        text: 'Dikkatli Ol',
        color: AppColors.warning,
        icon: Icons.warning_amber_outlined,
      );
    }
    if (s >= 20) {
      return (
        text: 'Zor Koşullar',
        color: AppColors.accent,
        icon: Icons.waves,
      );
    }
    return (
      text: 'Gitme!',
      color: AppColors.danger,
      icon: Icons.cancel_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = _scoreAccent(score.labelColor);
    final vd = _verdict(score.score);

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
                // Score row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.score}',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: isToday ? 68 : 54,
                        fontWeight: FontWeight.w900,
                        color: sc,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '/ 100',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              score.label,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sc,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Verdict banner
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
                      Icon(vd.icon, color: vd.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          vd.text,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: vd.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary
                if (score.summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    score.summary,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      color: AppColors.foam.withValues(alpha: 0.75),
                    ),
                  ),
                ],

                // Weather conditions
                if (weather != null) ...[
                  const SizedBox(height: 16),
                  _WeatherConditionsRow(weather: weather!),
                ],

                // Suggested species
                if (score.suggestedSpecies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Avlanacak Balıklar',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
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

                // Warning messages
                if (score.activeMessages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...score.activeMessages.take(2).map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.info_outline,
                              color: AppColors.accent,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weather Conditions Row ───────────────────────────────────────────────────

class _WeatherConditionsRow extends StatelessWidget {
  final WeatherModel weather;
  const _WeatherConditionsRow({required this.weather});

  @override
  Widget build(BuildContext context) {
    final chips = <({IconData icon, String value, String label})>[
      (
        icon: Icons.air,
        value: '${weather.windKmh.round()} km/h',
        label: 'Rüzgar',
      ),
      if (weather.waveHeight != null)
        (
          icon: Icons.waves,
          value: '${weather.waveHeight!.toStringAsFixed(1)} m',
          label: 'Dalga',
        ),
      (
        icon: Icons.thermostat_outlined,
        value: '${weather.tempCelsius.round()}°C',
        label: 'Hava',
      ),
      if (weather.seaSurfaceTemperature != null)
        (
          icon: Icons.water_outlined,
          value: '${weather.seaSurfaceTemperature!.round()}°C',
          label: 'Deniz',
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, color: AppColors.muted, size: 15),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.value,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foam,
                    ),
                  ),
                  Text(
                    c.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Bölge Seçici ─────────────────────────────────────────────────────────────

/// Balıkçım uzman sayfasındaki yatay kaydırmalı şehir seçici.
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
