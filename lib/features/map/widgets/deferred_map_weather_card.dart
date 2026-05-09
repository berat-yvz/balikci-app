import 'dart:async';

import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/map/widgets/weather_card.dart';

/// Harita açılışında [istanbulWeatherProvider] / balık skoru zincirini geciktirir;
/// ilk karelerde karolar ve etkileşim önceliklidir.
class DeferredMapWeatherCard extends StatefulWidget {
  const DeferredMapWeatherCard({super.key});

  static const _delay = Duration(milliseconds: 420);

  @override
  State<DeferredMapWeatherCard> createState() => _DeferredMapWeatherCardState();
}

class _DeferredMapWeatherCardState extends State<DeferredMapWeatherCard> {
  bool _showCard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(DeferredMapWeatherCard._delay, () {
        if (mounted) setState(() => _showCard = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCard) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.muted.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
      );
    }
    return const WeatherCard();
  }
}
