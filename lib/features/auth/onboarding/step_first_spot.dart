import 'package:flutter/material.dart';
import 'package:balikci_app/app/theme.dart';

class StepFirstSpot extends StatelessWidget {
  const StepFirstSpot({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.anchor,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 32),
          const Text(
            'Balıkçı Topluluğuna Hoş Geldin!',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Mera keşfet, av kaydet, rütbe kazan. Haydi başlayalım!',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // Rütbe Bilgileri Panosu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Column(
              children: [
                _RankRow(icon: '🪝', label: 'Acemi'),
                SizedBox(height: 8),
                _RankRow(icon: '🎣', label: 'Olta Kurdu'),
                SizedBox(height: 8),
                _RankRow(icon: '⚓', label: 'Usta'),
                SizedBox(height: 8),
                _RankRow(icon: '🌊', label: 'Deniz Reisi'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: () {
              // Dekoratif buton, asıl tetikleme onboarding_screen.dart 
              // altındaki 'Başla' butonunda olacaktır.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Haritayı Keşfet'),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String icon;
  final String label;

  const _RankRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
