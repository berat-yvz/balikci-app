import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/data/models/spot_model.dart';

/// Mera detay alt sheet (H3 read-only).
class SpotDetailSheet extends StatelessWidget {
  final SpotModel spot;
  const SpotDetailSheet({super.key, required this.spot});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spot.name, style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text('Gizlilik: ${spot.privacyLevel}', style: AppTextStyles.body),
            const SizedBox(height: 4),
            if (spot.type != null)
              Text('Tur: ${spot.type}', style: AppTextStyles.body),
            const SizedBox(height: 4),
            Text(
              'Konum: ${spot.lat.toStringAsFixed(5)}, ${spot.lng.toStringAsFixed(5)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 12),
            Text(
              spot.description?.trim().isNotEmpty == true
                  ? spot.description!
                  : 'Aciklama yok.',
              style: AppTextStyles.body,
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
