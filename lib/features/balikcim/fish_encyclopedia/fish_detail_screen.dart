import 'package:flutter/material.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';

const _turkishMonths = <String>[
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

/// Düğüm detayına benzer şekilde [Navigator.push] ile açılır.
class FishDetailScreen extends StatelessWidget {
  final FishEncyclopediaEntry fish;

  const FishDetailScreen({super.key, required this.fish});

  static String _formatMonths(List<int> months) {
    if (months.isEmpty) return '—';
    final sorted = [...months]..sort();
    return sorted.map((m) {
      if (m < 1 || m > 12) return '$m';
      return _turkishMonths[m - 1];
    }).join(', ');
  }

  static String _difficultyLabel(String raw) {
    switch (raw) {
      case 'kolay':
        return 'Kolay';
      case 'orta':
        return 'Orta';
      case 'zor':
        return 'Zor';
      default:
        return raw;
    }
  }

  static Color _difficultyColor(String raw) {
    switch (raw) {
      case 'kolay':
        return AppColors.success;
      case 'orta':
        return AppColors.warning;
      case 'zor':
        return AppColors.danger;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(fish.name),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fish.emoji,
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fish.name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fish.scientificName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoSection(
              title: 'Mevsimler',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.seasons.map((s) {
                  return _DetailSeasonChip(season: s);
                }).toList(),
              ),
            ),
            _InfoSection(
              title: 'En İyi Aylar',
              child: Text(
                _formatMonths(fish.bestMonths),
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
            _InfoSection(
              title: 'Yaşam Alanı',
              child: Text(
                fish.habitats.join(' • '),
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
            _InfoSection(
              title: 'Yemler',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.baits.map((b) {
                  return _TagChip(label: b);
                }).toList(),
              ),
            ),
            _InfoSection(
              title: 'Teknikler',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fish.techniques.map((t) {
                  return _TagChip(label: t);
                }).toList(),
              ),
            ),
            _InfoSection(
              title: 'Minimum Boy',
              child: Text(
                fish.minLegalSizeCm != null
                    ? '${fish.minLegalSizeCm} cm (av mevzuatı)'
                    : 'Kural yok',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
            _InfoSection(
              title: 'Ortalama Ağırlık',
              child: Text(
                '${fish.avgWeightKg.toStringAsFixed(1)} kg',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
            _InfoSection(
              title: 'Zorluk',
              child: Text(
                _difficultyLabel(fish.difficulty),
                style: AppTextStyles.body.copyWith(
                  color: _difficultyColor(fish.difficulty),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _InfoSection(
              title: 'İlginç Bilgi 💡',
              child: Text(
                fish.funFact,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.accent,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            _InfoSection(
              title: 'İpuçları 🎣',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fish.tips.map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $t',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            style: AppTextStyles.caption.copyWith(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailSeasonChip extends StatelessWidget {
  final String season;

  const _DetailSeasonChip({required this.season});

  Color _background() {
    switch (season) {
      case 'ilkbahar':
        return AppColors.primary;
      case 'yaz':
        return AppColors.accent;
      case 'sonbahar':
        return AppColors.seasonAutumn;
      case 'kis':
        return AppColors.secondary;
      default:
        return AppColors.muted;
    }
  }

  String _label() {
    switch (season) {
      case 'ilkbahar':
        return 'İlkbahar';
      case 'yaz':
        return 'Yaz';
      case 'sonbahar':
        return 'Sonbahar';
      case 'kis':
        return 'Kış';
      default:
        return season;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
