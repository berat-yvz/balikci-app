import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/features/weather/providers/istanbul_weather_provider.dart';

/// Harita üstünde gösterilen kompakt hava kartı — H9.
/// Weather page provider'ından veri alır, bağımsız API çağrısı yapmaz.
class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(istanbulWeatherProvider);

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
        if (w == null) return const SizedBox.shrink();

        final score = FishingWeatherUtils.getFishingScore(w);
        final scoreEmoji = FishingWeatherUtils.getScoreEmoji(score);
        final summary = FishingWeatherUtils.getSummary(w);

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
            children: [
              Row(
                children: [
                  // Sol: sıcaklık
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${w.tempCelsius.toStringAsFixed(0)}°C',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                        Text(
                          '${w.windKmh.toStringAsFixed(0)} km/s rüzgar',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sağ: skor
                  Column(
                    children: [
                      Text(scoreEmoji, style: const TextStyle(fontSize: 18)),
                      Text(
                        '$score',
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
              const SizedBox(height: 8),
              // Orta: balıkçı özeti
              Text(
                summary,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
