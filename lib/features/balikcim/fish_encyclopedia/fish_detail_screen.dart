import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';

String _mevsimTurkce(String s) {
  switch (s) {
    case 'ilkbahar':
      return '🌱 İlkbahar';
    case 'yaz':
      return '☀️ Yaz';
    case 'sonbahar':
      return '🍂 Sonbahar';
    case 'kis':
      return '❄️ Kış';
    default:
      return s;
  }
}

/// [Navigator.push] ile açılan sade balık detayı.
class FishDetailScreen extends StatelessWidget {
  final FishEncyclopediaEntry fish;

  const FishDetailScreen({super.key, required this.fish});

  @override
  Widget build(BuildContext context) {
    final mevsimMetni =
        fish.seasons.map(_mevsimTurkce).join('  •  ');

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(fish.name),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: AppColors.encyclopediaCard,
              child: Column(
                children: [
                  Text(
                    fish.emoji,
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fish.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fish.scientificName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white54,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: '🪝 Hangi Yemlere Gelir?',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.baits.map((b) => _Chip(b)).toList(),
              ),
            ),
            _Section(
              title: '📅 Hangi Mevsimde Tutulur?',
              child: Text(
                mevsimMetni.isEmpty ? '—' : mevsimMetni,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _Section(
              title: '🎣 Nasıl Avlanır?',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.techniques.map((t) => _Chip(t)).toList(),
              ),
            ),
            _Section(
              title: '💡 İpuçları',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fish.tips.map((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.accent,
                            fontSize: 16,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (fish.minLegalSizeCm != null)
              _Section(
                title: '📏 Minimum Boy (Av Mevzuatı)',
                child: Text(
                  '${fish.minLegalSizeCm} cm',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _Section(
              title: '💬 İlginç Bilgi',
              child: Text(
                fish.funFact,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white70,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }
}
