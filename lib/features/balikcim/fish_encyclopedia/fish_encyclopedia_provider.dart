import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';
import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_repository.dart';

final fishEncyclopediaProvider =
    FutureProvider<List<FishEncyclopediaEntry>>((ref) async {
  ref.keepAlive();
  final repo = FishEncyclopediaRepository();
  return repo.loadAll();
});

/// null = "Tümü"; diğerleri: `kiyi`, `acik_deniz`, `dip`, `gece`.
final selectedFishCategoryProvider = StateProvider<String?>((ref) => null);

final filteredFishProvider =
    Provider<AsyncValue<List<FishEncyclopediaEntry>>>((ref) {
  final allFish = ref.watch(fishEncyclopediaProvider);
  final category = ref.watch(selectedFishCategoryProvider);
  return allFish.whenData(
    (list) => category == null
        ? list
        : list.where((f) => f.category == category).toList(),
  );
});
