import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';

/// Hava kartı widget'ı — H9 sprint'te implemente edilecek.
class WeatherCardWidget extends StatelessWidget {
  // cleaned: placeholder widget, açıklayıcı empty-state karta çevrildi
  const WeatherCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hava Kartı',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Yakında bu alanda sıcaklık, rüzgar ve dalga bilgileri gösterilecek.',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
