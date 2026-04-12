import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
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
      data: (data) {
        final w = data.current;

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

        final firstSpecies = fishing?.suggestedSpecies.isNotEmpty == true
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
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
      },
    );
  }
}
