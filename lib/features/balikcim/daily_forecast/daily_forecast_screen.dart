import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/constants/weather_regions.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_detail_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_provider.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_screen.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

Future<void> _navigateToFishSpecies(
  BuildContext context,
  WidgetRef ref,
  FishSpeciesTip tip,
) async {
  try {
    final list = await ref.read(fishEncyclopediaProvider.future);
    FishEncyclopediaEntry? found;
    for (final e in list) {
      if (e.id == tip.id) {
        found = e;
        break;
      }
    }
    if (found == null) {
      final lower = tip.name.toLowerCase();
      for (final e in list) {
        if (e.name.toLowerCase() == lower) {
          found = e;
          break;
        }
      }
    }
    if (!context.mounted) return;
    if (found != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FishDetailScreen(fish: found!),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.navy,
          appBar: AppBar(
            title: const Text('Balık Bilgisi'),
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.foam,
          ),
          body: const FishEncyclopediaScreen(),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.navy,
          appBar: AppBar(
            title: const Text('Balık Bilgisi'),
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.foam,
          ),
          body: const FishEncyclopediaScreen(),
        ),
      ),
    );
  }
}

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

List<String> _additionalTips(FishingScore score) {
  final summaryNorm = _stripTipPrefix(score.summary).toLowerCase();
  final out = <String>[];
  for (final m in score.activeMessages) {
    final n = _stripTipPrefix(m).toLowerCase();
    if (n.isEmpty || n == summaryNorm) continue;
    out.add(m);
    if (out.length >= 5) break;
  }
  return out;
}

/// Balıkçım — günlük tahmin (skor motoru aynı; arayüz sade).
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
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
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
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.muted.withValues(alpha: 0.9),
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Veri gelmedi',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.foam,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aşağıdan yenileyin veya tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(istanbulWeatherProvider);
                    ref.invalidate(fishingScoreEngineProvider);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.foam,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tekrar dene',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final todayWeather = weatherAsync.valueOrNull?.current;
    final tomorrowScore = tomorrowAsync.valueOrNull;
    final tomorrowWeather = tomorrowWeatherAsync.valueOrNull;
    final regionName = weatherRegionDisplayNames[regionKey] ?? regionKey;

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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _RegionTitle(regionName: regionName),
                  const SizedBox(height: 14),
                  const _ForecastRegionSelector(),
                  const SizedBox(height: 22),
                  _ForecastInsightCard(
                    title: 'Bugün',
                    date: now,
                    score: todayScore,
                    weather: todayWeather,
                    emphasize: true,
                  ),
                  const SizedBox(height: 14),
                  if (tomorrowScore != null)
                    _ForecastInsightCard(
                      title: 'Yarın',
                      date: tomorrow,
                      score: tomorrowScore,
                      weather: tomorrowWeather,
                      emphasize: false,
                    )
                  else
                    const _TomorrowPlaceholder(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bölge başlığı (tek satır, sakin) ─────────────────────────────────────────

class _RegionTitle extends StatelessWidget {
  final String regionName;
  const _RegionTitle({required this.regionName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.place_outlined,
          size: 18,
          color: AppColors.muted.withValues(alpha: 0.95),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            regionName,
            style: AppTextStyles.body.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.foam,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ana / yarın kartı ───────────────────────────────────────────────────────

class _ForecastInsightCard extends ConsumerWidget {
  final String title;
  final DateTime date;
  final FishingScore score;
  final WeatherModel? weather;
  final bool emphasize;

  const _ForecastInsightCard({
    required this.title,
    required this.date,
    required this.score,
    required this.weather,
    required this.emphasize,
  });

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _days = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  static Color _accent(String labelColor) {
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

  /// Skor aralığı → tek kelime özet (uzun cümle yok).
  static String _toneWord(int s) {
    if (s >= 75) return 'İyi';
    if (s >= 55) return 'Uygun';
    if (s >= 40) return 'Orta';
    if (s >= 20) return 'Zor';
    return 'Uygun değil';
  }

  String _dateShort(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} · ${_days[d.weekday - 1]}';

  void _openDetailSheet(BuildContext context) {
    final extras = _additionalTips(score);
    final summary = score.summary.trim();
    if (summary.isEmpty && extras.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.encyclopediaCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Ek bilgi',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.foam,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.foam.withValues(alpha: 0.82),
                    ),
                  ),
                if (summary.isNotEmpty && extras.isNotEmpty)
                  const SizedBox(height: 16),
                ...extras.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = _accent(score.labelColor);
    final tone = _toneWord(score.score);
    final hasDetail =
        score.summary.trim().isNotEmpty || _additionalTips(score).isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.encyclopediaCard,
            AppColors.encyclopediaCard.withValues(alpha: 0.92),
            const Color(0xFF152A3D),
          ],
        ),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.38)
              : AppColors.muted.withValues(alpha: 0.18),
          width: emphasize ? 1.25 : 1,
        ),
        boxShadow: emphasize
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          emphasize ? 22 : 18,
          emphasize ? 22 : 18,
          emphasize ? 22 : 18,
          emphasize ? 20 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: emphasize ? 11 : 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: emphasize
                            ? AppColors.primary.withValues(alpha: 0.95)
                            : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateShort(date),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ac.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    tone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ac,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: emphasize ? 22 : 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${score.score}',
                  style: TextStyle(
                    fontSize: emphasize ? 56 : 44,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: ac,
                    letterSpacing: -2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 8),
                  child: Text(
                    '/100',
                    style: TextStyle(
                      fontSize: emphasize ? 15 : 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        score.label,
                        style: TextStyle(
                          fontSize: emphasize ? 19 : 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foam,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (score.score.clamp(0, 100)) / 100.0,
                          minHeight: emphasize ? 7 : 6,
                          backgroundColor:
                              AppColors.surface.withValues(alpha: 0.85),
                          color: ac,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (weather != null) ...[
              SizedBox(height: emphasize ? 22 : 16),
              _WeatherStatRow(weather: weather!),
            ],
            if (score.suggestedSpecies.isNotEmpty) ...[
              SizedBox(height: emphasize ? 18 : 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(
                      Icons.set_meal_outlined,
                      size: 16,
                      color: AppColors.muted.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    ...score.suggestedSpecies.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _navigateToFishSpecies(context, ref, s),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foam,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            if (hasDetail) ...[
              SizedBox(height: emphasize ? 14 : 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openDetailSheet(context),
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Detayları göster',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.primary.withValues(alpha: 0.95),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Kompakt hava (ikon + rakam, uzun cümle yok) ───────────────────────────────

class _WeatherStatRow extends StatelessWidget {
  final WeatherModel weather;

  const _WeatherStatRow({required this.weather});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String value, String label})>[
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
        icon: Icons.thermostat,
        value: '${weather.tempCelsius.round()}°',
        label: 'Hava',
      ),
      if (weather.seaSurfaceTemperature != null)
        (
          icon: Icons.water_drop_outlined,
          value: '${weather.seaSurfaceTemperature!.round()}°',
          label: 'Deniz',
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: AppColors.muted.withValues(alpha: 0.18),
              ),
            Expanded(
              child: _MiniStat(
                icon: items[i].icon,
                value: items[i].value,
                label: items[i].label,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.92)),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.foam,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted.withValues(alpha: 0.92),
          ),
        ),
      ],
    );
  }
}

// ── Bölge seçici ─────────────────────────────────────────────────────────────

/// [selectedWeatherRegionProvider] değişince skorlar güncellenir.
class _ForecastRegionSelector extends ConsumerWidget {
  const _ForecastRegionSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedWeatherRegionProvider);
    return SizedBox(
      height: 38,
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
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.muted.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.foam : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Yarın verisi yok ─────────────────────────────────────────────────────────

class _TomorrowPlaceholder extends StatelessWidget {
  const _TomorrowPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.muted.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Yarın için veri hazır değil — yenileyin.',
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
