import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/spot_model.dart';

/// Mera detay alt sheet (H3 read-only + H4 sahip düzenleme).
class SpotDetailSheet extends StatelessWidget {
  final SpotModel spot;
  const SpotDetailSheet({super.key, required this.spot});

  Future<void> _openDirections(BuildContext context) async {
    final label = Uri.encodeComponent(spot.name);
    final geo = Uri.parse(
      'geo:${spot.lat},${spot.lng}?q=${spot.lat},${spot.lng}($label)',
    );
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${spot.lat},${spot.lng}',
    );
    try {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    try {
      if (await launchUrl(maps, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Harita acilamadi'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _openEdit(BuildContext context) {
    final router = GoRouter.of(context);
    final s = spot;
    Navigator.of(context).pop();
    Future.microtask(() => router.push('/map/edit-spot', extra: s));
  }

  void _openCheckin(BuildContext context) {
    final router = GoRouter.of(context);
    final s = spot;
    Navigator.of(context).pop();
    Future.microtask(() => router.push('/checkin/${s.id}'));
  }

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.auth.currentUser?.id;
    final isOwner = uid != null && uid == spot.userId;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isOwner)
                  TextButton(
                    onPressed: () => _openEdit(context),
                    child: const Text('Duzenle'),
                  ),
                TextButton(
                  onPressed: () => _openCheckin(context),
                  child: const Text('Check-in'),
                ),
                TextButton(
                  onPressed: () => _openDirections(context),
                  child: const Text('Yol tarifi'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
