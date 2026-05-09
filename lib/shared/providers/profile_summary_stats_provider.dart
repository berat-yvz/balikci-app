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

/// Profil ekranı istatistikleri — autoDispose değil; tekrar girişte anında gösterir.
final profileSummaryStatsProvider =
    FutureProvider.family<ProfileSummaryStats, String>((ref, userId) {
      return ProfileSummaryStats.fetchForUser(userId);
    });
