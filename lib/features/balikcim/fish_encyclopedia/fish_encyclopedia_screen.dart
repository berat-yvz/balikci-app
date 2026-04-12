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
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredFishProvider);
    final selected = ref.watch(selectedFishCategoryProvider);

    return ColoredBox(
      color: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
        child: SizedBox(
          height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
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
    final baitLine = entry.baits.take(2).join(' • ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.encyclopediaCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Text(
          entry.emoji,
          style: AppTextStyles.h2.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.normal,
          ),
        ),
        title: Text(
          entry.name,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          baitLine.isEmpty ? '—' : baitLine,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
          size: 24,
        ),
        onTap: onTap,
      ),
    );
  }
}
