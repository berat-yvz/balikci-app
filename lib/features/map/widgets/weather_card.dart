import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/location_service.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/core/utils/fishing_weather_utils.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Harita üstünde gösterilen kompakt hava kartı — H9.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherModel? _weather;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      WeatherModel? weather;
      if (pos != null) {
        weather = await WeatherService.getWeatherForLocation(
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
      // Konum alınamazsa İstanbul'u göster
      weather ??= await WeatherService.getWeatherByRegionKey('istanbul');
      if (!mounted) return;
      setState(() => _weather = weather);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
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
      );
    }

    final w = _weather;
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
      child: Row(
        children: [
          // Sol: sıcaklık
          Column(
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
          const SizedBox(width: 12),
          // Orta: balıkçı özeti
          Expanded(
            child: Text(
              summary,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }
}
