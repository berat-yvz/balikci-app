import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:balikci_app/features/balikcim/fish_encyclopedia/fish_encyclopedia_model.dart';

class FishEncyclopediaRepository {
  static const _assetPath = 'assets/fishing/fish_encyclopedia.json';
  static const _istanbulSpeciesPath =
      'assets/fishing/fish_species_istanbul.json';

  Future<List<FishEncyclopediaEntry>> loadAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['fish'] as List<dynamic>? ?? const [];
    final gearById = await _loadIstanbulGearByFishId();
    return list
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final base = FishEncyclopediaEntry.fromJson(row);
          final gear = gearById[base.id];
          if (gear == null || !gear.hasDisplayableData) return base;
          return base.withIstanbulGear(gear);
        })
        .toList(growable: false);
  }

  /// `fish_species_istanbul.json` → `species[].gear_map`, balık `id` ile eşleşir.
  Future<Map<String, FishIstanbulGearRecommendation>>
      _loadIstanbulGearByFishId() async {
    try {
      final raw = await rootBundle.loadString(_istanbulSpeciesPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final species = decoded['species'] as List<dynamic>? ?? const [];
      final map = <String, FishIstanbulGearRecommendation>{};
      for (final row in species.whereType<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        final gm = row['gear_map'] as Map<String, dynamic>?;
        if (id == null || gm == null) continue;
        final gear = FishIstanbulGearRecommendation.fromGearMapJson(gm);
        if (gear.hasDisplayableData) map[id] = gear;
      }
      void mirrorId(String canonical, String alias) {
        final g = map[canonical];
        if (g != null) map[alias] = g;
      }

      // Ansiklopedi `yayinbaligi` — İstanbul dosyası `yayin_baligi`
      mirrorId('yayin_baligi', 'yayinbaligi');
      return map;
    } catch (_) {
      return {};
    }
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
