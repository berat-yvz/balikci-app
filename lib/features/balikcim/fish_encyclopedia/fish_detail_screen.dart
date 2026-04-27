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

String _ayAdiTr(int month) {
  const names = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  if (month < 1 || month > 12) return '$month';
  return names[month];
}

String _zorlukEtiket(String d) {
  return switch (d) {
    'kolay' => 'Kolay',
    'orta' => 'Orta',
    'zor' => 'Zor',
    _ => d,
  };
}

Color _zorlukRenk(String d) {
  return switch (d) {
    'kolay' => AppColors.success,
    'zor' => AppColors.danger,
    _ => AppColors.warning,
  };
}

/// [Navigator.push] ile açılan balık detayı — bölüm sırası İstanbul Olta El Kitabı akışına göre.
class FishDetailScreen extends StatelessWidget {
  final FishEncyclopediaEntry fish;

  const FishDetailScreen({super.key, required this.fish});

  @override
  Widget build(BuildContext context) {
    final mevsimMetni =
        fish.seasons.map(_mevsimTurkce).join('  •  ');
    final aylarMetni = fish.bestMonths.isEmpty
        ? '—'
        : fish.bestMonths.map(_ayAdiTr).join(', ');

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(
          '${fish.emoji} ${fish.name}',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 20),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fish.scientificName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white54,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fishCategoryDisplayLabel(fish.category),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _zorlukRenk(fish.difficulty).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _zorlukRenk(fish.difficulty).withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    'Zorluk: ${_zorlukEtiket(fish.difficulty)}',
                    style: AppTextStyles.body.copyWith(
                      color: _zorlukRenk(fish.difficulty),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            _Section(
              title: '🌤️ Hangi mevsimde tutulur?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mevsimMetni.isEmpty ? '—' : mevsimMetni,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'En iyi aylar',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white60,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aylarMetni,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.foam,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (fish.habitats.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Öne çıkan yerler',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...fish.habitats.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.accent,
                                fontSize: 17,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                h,
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            _Section(
              title: '🪱 Hangi yemlere gelir?',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.baits.map((b) => _Chip(b)).toList(),
              ),
            ),
            _Section(
              title: '🎣 Nasıl avlanır?',
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.accent,
                            fontSize: 17,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white70,
                              fontSize: 16,
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
                title: '📏 Minimum boy (av mevzuatı)',
                child: Text(
                  '${fish.minLegalSizeCm} cm',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💬 İlginç bilgi',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.foam,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      fish.funFact,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.all(18),
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          fontSize: 16,
        ),
      ),
    );
  }
}
