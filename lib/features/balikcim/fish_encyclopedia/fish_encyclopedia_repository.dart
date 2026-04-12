import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';

class FishEncyclopediaRepository {
  static const _assetPath = 'assets/fishing/fish_encyclopedia.json';

  Future<List<FishEncyclopediaEntry>> loadAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['fish'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FishEncyclopediaEntry.fromJson)
        .toList(growable: false);
  }

  /// [category] null ise tüm liste döner.
  List<FishEncyclopediaEntry> filterByCategory(
    List<FishEncyclopediaEntry> entries,
    String? category,
  ) {
    if (category == null || category.isEmpty) return entries;
    return entries
        .where((f) => f.category == category)
        .toList(growable: false);
  }

  /// [season] değeri `ilkbahar` | `yaz` | `sonbahar` | `kis` olmalıdır.
  List<FishEncyclopediaEntry> filterBySeason(
    List<FishEncyclopediaEntry> entries,
    String season,
  ) {
    return entries
        .where((e) => e.seasons.contains(season))
        .toList(growable: false);
  }
}
