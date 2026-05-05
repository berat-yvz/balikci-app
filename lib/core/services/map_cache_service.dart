import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'package:balikci_app/core/constants/app_constants.dart';

/// FMTC tile cache yönetim servisi.
///
/// FMTC 9.x public API:
///   - [FMTCStore.manage.removeTilesOlderThan] — TTL eviction
///   - [FMTCStore.manage.reset]               — tüm tile'ları sil
///   - [FMTCStore.stats.size]                 — KiB cinsinden toplam boyut
///
/// Boyut limiti [FMTCTileProviderSettings.maxStoreLength] ile tile sayısı
/// bazında da uygulanır (map_screen.dart'ta provider kurulumunda).
/// Bu servis ise uygulama açılışında ve harita ekranında MB + TTL bazlı
/// temizlik yapar.
class MapCacheService {
  const MapCacheService._();

  static String get storeName => AppConstants.fmtcStoreName;

  static const double _maxCacheKib =
      AppConstants.fmtcMaxCacheMb * 1024.0;

  static const Duration _tileTtl =
      Duration(days: AppConstants.fmtcMaxCacheDays);

  /// Store'un hazır olup olmadığını kontrol eder.
  /// FMTC başlatılmadıysa `false` döner — sonrasındaki tüm işlemler atlanır.
  static Future<bool> _isReady() async {
    try {
      return await FMTCStore(storeName).manage.ready;
    } catch (_) {
      return false;
    }
  }

  /// Cache limitlerini uygular:
  ///   1. TTL süresi dolmuş tile'ları kaldırır.
  ///   2. Toplam boyut [AppConstants.fmtcMaxCacheMb] MB'yi aşıyorsa
  ///      store sıfırlanır (LRU yerine bütünsel temizlik —
  ///      FMTC 9 public API byte bazlı LRU sunmaz).
  static Future<void> applyLimits() async {
    try {
      if (!await _isReady()) return;

      final store = FMTCStore(storeName);

      // TTL eviction
      await store.manage.removeTilesOlderThan(
        expiry: DateTime.now().subtract(_tileTtl),
      );

      // Boyut kontrolü — limit aşıldıysa store'u sıfırla
      final sizeKib = await store.stats.size;
      if (sizeKib > _maxCacheKib) {
        await store.manage.reset();
        debugPrint(
          'FMTC: cache boyut limitini aştı '
          '(${(sizeKib / 1024).toStringAsFixed(1)} MB > '
          '${AppConstants.fmtcMaxCacheMb} MB), sıfırlandı.',
        );
      }
    } catch (e) {
      debugPrint('FMTC cache limitleri uygulanamadı: $e');
    }
  }

  /// Mevcut cache boyutunu MB cinsinden döndürür.
  /// FMTC hazır değilse veya hata oluşursa 0.0 döner.
  static Future<double> getCacheSizeMb() async {
    try {
      if (!await _isReady()) return 0.0;
      final sizeKib = await FMTCStore(storeName).stats.size;
      return sizeKib / 1024.0;
    } catch (e) {
      debugPrint('FMTC cache boyutu alınamadı: $e');
      return 0.0;
    }
  }

  /// Tüm cache tile'larını siler (store yapısı korunur).
  static Future<void> clearCache() async {
    try {
      if (!await _isReady()) return;
      await FMTCStore(storeName).manage.reset();
    } catch (e) {
      debugPrint('FMTC cache temizlenemedi: $e');
    }
  }

  /// TTL süresi dolmuş tile'ları temizler.
  /// Uygulama açılışında ve harita ekranında fire-and-forget çağrılır.
  static Future<void> evictOldTiles() async {
    try {
      if (!await _isReady()) return;
      await FMTCStore(storeName).manage.removeTilesOlderThan(
        expiry: DateTime.now().subtract(_tileTtl),
      );
    } catch (e) {
      debugPrint('FMTC TTL temizliği başarısız: $e');
    }
  }
}
