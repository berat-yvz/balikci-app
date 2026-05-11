import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/fishing_score.dart';
import 'package:balikci_app/data/models/weather_model.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';
import 'package:balikci_app/shared/providers/fishing_score_provider.dart';

Color _mapAccentFromLabelColor(String labelColor) {
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

/// Harita üstünde gösterilen kompakt hava kartı — H9.
/// Weather page provider'ından veri alır, bağımsız API çağrısı yapmaz.
class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);
    final fishingAsync = ref.watch(fishingScoreProvider);

    return weatherAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.muted.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (data) =>
          _buildExpandedWeatherCardBody(data.current, fishingAsync),
    );
  }
}

/// Geniş harita hava kartı gövdesi — [WeatherCard] ve [MapWeatherExpandableCard] paylaşır.
Widget _buildExpandedWeatherCardBody(
  WeatherModel w,
  AsyncValue<FishingScore> fishingAsync,
) {
  final fishing = fishingAsync.when(
    data: (v) => v,
    loading: () => null,
    error: (Object e, StackTrace stackTrace) => null,
  );

  final int score;
  final String label;
  if (fishing != null) {
    score = fishing.score;
    label = fishing.label;
  } else {
    score = FishingWeatherUtils.getFishingScore(w);
    label = score >= 70 ? 'İyi' : (score >= 40 ? 'Orta' : 'Kötü');
  }

  final accent = fishing != null
      ? _mapAccentFromLabelColor(fishing.labelColor)
      : (score >= 70
          ? AppColors.success
          : (score >= 40 ? AppColors.secondary : AppColors.danger));

  final firstSpecies =
      fishing?.suggestedSpecies.isNotEmpty == true
          ? fishing!.suggestedSpecies.first
          : null;
  final todayLine = firstSpecies != null
      ? 'Bugün: ${firstSpecies.name}${firstSpecies.isInSeason ? ' ✓' : ''}'
      : null;

  return Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.muted.withValues(alpha: 0.2),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '${w.tempCelsius.toStringAsFixed(0)}°C',
                        style: AppTextStyles.h3.copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.location_city,
                        size: 12,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  Text(
                    '💨 ${w.windKmh.toStringAsFixed(0)} km/s'
                    '${w.waveHeight != null ? '  🌊 ${w.waveHeight!.toStringAsFixed(1)} m' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1,
                  ),
                ),
                Text(
                  '/100 · $label',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (todayLine != null && firstSpecies != null) ...[
          const SizedBox(height: 6),
          Text(
            todayLine,
            style: AppTextStyles.caption.copyWith(
              color: firstSpecies.isInSeason
                  ? AppColors.success
                  : AppColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildCollapsedWeatherPillBody(
  WeatherModel w,
  AsyncValue<FishingScore> fishingAsync,
) {
  final fishing = fishingAsync.when(
    data: (v) => v,
    loading: () => null,
    error: (Object e, StackTrace stackTrace) => null,
  );

  final int score = fishing != null
      ? fishing.score
      : FishingWeatherUtils.getFishingScore(w);
  final temp = w.tempCelsius.toStringAsFixed(0);

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wb_sunny_outlined,
            size: 14,
            color: AppColors.foam,
          ),
          const SizedBox(width: 4),
          Text(
            '$temp° · $score',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Harita üstü hava/skor — tek widget’ta defer + geniş/dar geçiş; harita gövdesini yeniden boyamaz.
class MapWeatherExpandableCard extends ConsumerStatefulWidget {
  const MapWeatherExpandableCard({super.key});

  @override
  ConsumerState<MapWeatherExpandableCard> createState() =>
      _MapWeatherExpandableCardState();
}

class _MapWeatherExpandableCardState extends ConsumerState<MapWeatherExpandableCard> {
  static const _deferDelay = Duration(milliseconds: 420);

  bool _deferDone = false;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(_deferDelay, () {
        if (mounted) setState(() => _deferDone = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_deferDone) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _MapWeatherDeferSkeleton(),
      );
    }

    final weatherAsync = ref.watch(istanbulWeatherProvider);
    final fishingAsync = ref.watch(fishingScoreProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: RepaintBoundary(
        child: weatherAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.muted.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (Object error, StackTrace stackTrace) =>
              const SizedBox.shrink(),
          data: (IstanbulWeatherData pack) => AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            clipBehavior: Clip.hardEdge,
            child: _expanded
                ? KeyedSubtree(
                    key: const ValueKey<Object>('map_wx_open'),
                    child: _buildExpandedWeatherCardBody(
                      pack.current,
                      fishingAsync,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey<Object>('map_wx_shut'),
                    child: _buildCollapsedWeatherPillBody(
                      pack.current,
                      fishingAsync,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MapWeatherDeferSkeleton extends StatelessWidget {
  const _MapWeatherDeferSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }
}
