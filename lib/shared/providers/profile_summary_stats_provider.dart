import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';

/// Profil özet kartları — üç paralel sorgu; `limit(1)` + `count(exact)` ile küçük gövde.
class ProfileSummaryStats {
  final int postCount;
  final int spotCount;
  final int checkinCount;

  const ProfileSummaryStats({
    required this.postCount,
    required this.spotCount,
    required this.checkinCount,
  });

  static Future<int> _exactCount({
    required PostgrestFilterBuilder<PostgrestList> query,
  }) async {
    try {
      final res = await query.limit(1).count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  static Future<ProfileSummaryStats> fetchForUser(String userId) async {
    final client = SupabaseService.client;

    final posts = client
        .from('posts')
        .select('id')
        .eq('user_id', userId)
        .eq('is_deleted', false);

    final spots =
        client.from('fishing_spots').select('id').eq('user_id', userId);

    final checkins =
        client.from('checkins').select('id').eq('user_id', userId);

    final results = await Future.wait([
      _exactCount(query: posts),
      _exactCount(query: spots),
      _exactCount(query: checkins),
    ]);

    return ProfileSummaryStats(
      postCount: results[0],
      spotCount: results[1],
      checkinCount: results[2],
    );
  }
}

/// Profil "İstatistikler" sekmesi — özet sayılar + check-in balık türleri özeti.
/// [fishActivityCount]: en az bir balık türü bildirilmiş check-in sayısı.
class ProfileAnalyticsTab {
  final int totalSpots;
  final int totalCheckins;
  final int fishActivityCount;
  final String? topFishSpecies;
  final int topFishSpeciesHits;

  const ProfileAnalyticsTab({
    required this.totalSpots,
    required this.totalCheckins,
    required this.fishActivityCount,
    required this.topFishSpecies,
    required this.topFishSpeciesHits,
  });

  static Future<ProfileAnalyticsTab> fetchForUser(String userId) async {
    final basic = await ProfileSummaryStats.fetchForUser(userId);
    final fish = await _fetchFishAgg(userId);
    return ProfileAnalyticsTab(
      totalSpots: basic.spotCount,
      totalCheckins: basic.checkinCount,
      fishActivityCount: fish.taggedCheckins,
      topFishSpecies: fish.topSpecies,
      topFishSpeciesHits: fish.topHits,
    );
  }

  static Future<
      ({
        int taggedCheckins,
        String? topSpecies,
        int topHits,
      })> _fetchFishAgg(String userId) async {
    try {
      final res = await SupabaseService.client
          .from('checkins')
          .select('fish_species')
          .eq('user_id', userId)
          .limit(800);

      final rows = res as List<dynamic>;
      var tagged = 0;
      final counts = <String, int>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final raw = row['fish_species'];
        if (raw is! List || raw.isEmpty) continue;
        tagged++;
        for (final item in raw) {
          final name = item?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          counts[name] = (counts[name] ?? 0) + 1;
        }
      }
      String? topName;
      var topN = 0;
      counts.forEach((k, v) {
        if (v > topN) {
          topN = v;
          topName = k;
        }
      });
      return (
        taggedCheckins: tagged,
        topSpecies: topName,
        topHits: topN,
      );
    } catch (_) {
      return (
        taggedCheckins: 0,
        topSpecies: null,
        topHits: 0,
      );
    }
  }
}

/// Gönderi özet kartlarıyla aynı sayaçları içerir; sekme açılınca balık özeti eklenir.
final profileAnalyticsTabProvider =
    FutureProvider.autoDispose.family<ProfileAnalyticsTab, String>(
  (ref, userId) => ProfileAnalyticsTab.fetchForUser(userId),
);

/// Profil ekranı istatistikleri — autoDispose değil; tekrar girişte anında gösterir.
final profileSummaryStatsProvider =
    FutureProvider.family<ProfileSummaryStats, String>((ref, userId) {
      return ProfileSummaryStats.fetchForUser(userId);
    });
