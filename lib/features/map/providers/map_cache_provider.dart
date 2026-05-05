import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/map_cache_service.dart';

/// Mevcut tile cache boyutunu MB cinsinden döndürür.
/// Ayarlar ekranında cache kullanımını göstermek için kullanılır.
final mapCacheSizeProvider = FutureProvider.autoDispose<double>((ref) async {
  return MapCacheService.getCacheSizeMb();
});
