import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/theme.dart';

class StepFirstSpot extends StatelessWidget {
  final Future<void> Function()? onFinish;
  const StepFirstSpot({super.key, this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.anchor, size: 80, color: AppColors.primary),
          const SizedBox(height: 32),
          const Text(
            'Her Şey Hazır! 🎣',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Haritayı aç, yakınındaki meralara bak.\nİlk bildirimi yap, topluluğa katıl.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.map_rounded,
                  title: 'Haritayı Keşfet',
                  description: 'Yakınındaki meraları gör',
                  onTap: () => context.go(AppRoutes.home),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_location_rounded,
                  title: 'Mera Ekle',
                  description: 'Bildiğin bir mera var mı?',
                  onTap: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              await onFinish?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Hadi Başlayalım!'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                color: AppColors.foam,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.body.copyWith(
                color: AppColors.foam.withValues(alpha: 0.60),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
