import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_detail_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_provider.dart';

/// Balık ansiklopedisi listesi — [BalikcimScreen] TabBarView içine gömülür; Scaffold yok.
class FishEncyclopediaScreen extends ConsumerWidget {
  const FishEncyclopediaScreen({super.key});

  static const _filters = <(String label, String? value)>[
    ('Tümü', null),
    ('Kıyı', 'kiyi'),
    ('Açık Deniz', 'acik_deniz'),
    ('Dip', 'dip'),
    ('Gece', 'gece'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredFishProvider);
    final selected = ref.watch(selectedFishCategoryProvider);

    return ColoredBox(
      color: AppColors.leaderboardBanner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: _filters.map((f) {
                final isSelected = selected == f.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryFilterChip(
                    label: f.$1,
                    selected: isSelected,
                    onTap: () {
                      ref.read(selectedFishCategoryProvider.notifier).state =
                          f.$2;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Bu kategoride balık bulunamadı.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    return _FishCard(
                      entry: list[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FishDetailScreen(fish: list[index]),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.foam),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Liste yüklenemedi: $e',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FishCard extends StatelessWidget {
  final FishEncyclopediaEntry entry;
  final VoidCallback onTap;

  const _FishCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 8,
        isThreeLine: true,
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            entry.emoji,
            style: AppTextStyles.h2.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        title: Text(
          entry.name,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              entry.scientificName,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: entry.seasons.map(_SeasonChip.new).toList(),
            ),
          ],
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
        onTap: onTap,
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  final String season;

  const _SeasonChip(this.season);

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
