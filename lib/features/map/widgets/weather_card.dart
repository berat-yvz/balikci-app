import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/weather_service.dart';
import 'package:balikci_app/core/utils/weather_translator.dart';
import 'package:balikci_app/data/models/weather_model.dart';

/// Harita alt şeridi için compact hava kartı.
///
/// Bu widget, [WeatherService.getWeatherForLocation] ile `lat/lng` bazlı
/// `weather_cache` içinden en yakın veriyi çeker.
class WeatherCard extends StatelessWidget {
  final double lat;
  final double lng;

  const WeatherCard({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherModel?>(
      future: WeatherService.getWeatherForLocation(lat: lat, lng: lng),
      builder: (context, snapshot) {
        final w = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _cardSkeleton();
        }

        if (w == null) {
          return _cardError();
        }

        final wind = w.windKmh;
        final wave = w.waveHeight ?? 0;
        final temp = w.tempCelsius;

        final translated = WeatherTranslator.translate(
          windSpeedKmh: wind,
          waveHeightM: wave,
          tempC: temp,
          weatherCode: w.weatherCode,
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 92,
                decoration: BoxDecoration(
                  color: translated.color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            translated.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              translated.summary,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        translated.fishingAdvice,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.thermostat_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            '${w.tempCelsius.round()}°C',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.air_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            '${w.windKmh.round()} km/h',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (w.waveHeight != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Dalga: ${w.waveHeight!.toStringAsFixed(1)}m',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cardSkeleton() {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _cardError() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hava verisi bulunamadı.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

