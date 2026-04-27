import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_detail_screen.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_provider.dart';

/// Balık ansiklopedisi listesi — [BalikcimScreen] TabBarView içine gömülür; Scaffold yok.
class FishEncyclopediaScreen extends ConsumerStatefulWidget {
  const FishEncyclopediaScreen({super.key});

  @override
  ConsumerState<FishEncyclopediaScreen> createState() =>
      _FishEncyclopediaScreenState();
}

class _FishEncyclopediaScreenState extends ConsumerState<FishEncyclopediaScreen> {
  static const _filters = <(String label, String? value)>[
    ('Tümü', null),
    ('Göçmen', 'goc'),
    ('Kıyı', 'kiyi'),
    ('Açık Deniz', 'acik_deniz'),
    ('Dip', 'dip'),
    ('Tatlısu', 'tatli_su'),
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchController.text.trim().toLowerCase();
      if (!mounted) return;
      setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<FishEncyclopediaEntry> _applyLocalFilter(List<FishEncyclopediaEntry> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((f) {
      final n = f.name.toLowerCase();
      final s = f.scientificName.toLowerCase();
      return n.contains(_searchQuery) || s.contains(_searchQuery);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredFishProvider);
    final selected = ref.watch(selectedFishCategoryProvider);

    return ColoredBox(
      color: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 17,
              ),
              decoration: InputDecoration(
                hintText: 'Balık ara (ad veya bilimsel ad)...',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 26),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Temizle',
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.encyclopediaCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
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
                final visible = _applyLocalFilter(list);
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 72,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            list.isEmpty
                                ? 'Bu kategoride balık bulunamadı.'
                                : 'Aramanıza uygun balık yok.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h3.copyWith(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Farklı bir kategori seçin veya aramayı değiştirin.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final fish = visible[index];
                    return _FishCard(
                      entry: fish,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FishDetailScreen(fish: fish),
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
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
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
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                fontSize: 15,
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minVerticalPadding: 14,
        leading: Text(
          entry.emoji,
          style: AppTextStyles.h2.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.normal,
          ),
        ),
        title: Text(
          entry.name,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fishCategoryDisplayLabel(entry.category),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                baitLine.isEmpty ? '—' : baitLine,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white38,
          size: 28,
        ),
        onTap: onTap,
      ),
    );
  }
}
