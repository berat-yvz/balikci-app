import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/user_model.dart';

/// Toplam gölge puan özeti (alıcı perspektifi).
class ShadowPointSummary {
  final int total;
  final int eventCount;

  const ShadowPointSummary({required this.total, required this.eventCount});
}

/// Tek bir gölge puan olayı (liste / sheet için).
class ShadowPointEvent {
  final String id;
  final String giverUsername;
  final String? spotName;
  final int points;
  final DateTime createdAt;

  const ShadowPointEvent({
    required this.id,
    required this.giverUsername,
    this.spotName,
    required this.points,
    required this.createdAt,
  });

  String get displayText =>
      '$giverUsername senin ${spotName ?? 'merana'} gidip av paylaştı!';
}

/// `shadow_points` okuma — RLS: alıcı yalnızca kendi kayıtlarını görür.
///
/// `source_type = post` için `source_id` gönderi uuid'sidir; mera adı `posts` →
/// `fishing_spots` ile batch yüklenir.
class ShadowPointRepository {
  ShadowPointRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<ShadowPointSummary> getUserShadowPoints(String userId) async {
    try {
      final rows = await _client
          .from('shadow_points')
          .select('points')
          .eq('receiver_id', userId);

      final list = rows as List<dynamic>? ?? const [];
      var total = 0;
      for (final r in list) {
        final m = r as Map<String, dynamic>;
        total += (m['points'] as num?)?.toInt() ?? 0;
      }
      return ShadowPointSummary(total: total, eventCount: list.length);
    } catch (e, st) {
      debugPrint('ShadowPointRepository.getUserShadowPoints: $e\n$st');
      return const ShadowPointSummary(total: 0, eventCount: 0);
    }
  }

  Future<List<ShadowPointEvent>> getRecentShadowEvents(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final rows = await _client
          .from('shadow_points')
          .select('id, points, created_at, source_type, source_id, giver_id')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final rawList = rows as List<dynamic>? ?? const [];
      if (rawList.isEmpty) return [];

      final events = <ShadowPointEvent>[];
      final giverIds = <String>{};
      final postIds = <String>[];

      for (final r in rawList) {
        final m = r as Map<String, dynamic>;
        final gid = m['giver_id'] as String?;
        if (gid != null) giverIds.add(gid);
        if ((m['source_type'] as String?) == 'post') {
          final pid = m['source_id'] as String?;
          if (pid != null) postIds.add(pid);
        }
      }

      final usernameByGiver = await _fetchGiverUsernames(giverIds);
      final spotNameByPostId = await _fetchSpotNamesForPosts(postIds);

      for (final r in rawList) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        final gid = m['giver_id'] as String?;
        final pts = (m['points'] as num?)?.toInt() ?? 0;
        final createdRaw = m['created_at'];
        if (id == null || gid == null || createdRaw == null) continue;

        DateTime createdAt;
        if (createdRaw is DateTime) {
          createdAt = createdRaw;
        } else {
          createdAt = DateTime.tryParse(createdRaw.toString()) ?? DateTime.now();
        }

        final rawName = usernameByGiver[gid];
        final displayName = UserModel.displayUsername(
          rawUsername: rawName,
          userId: gid,
        );

        final sourceType = m['source_type'] as String?;
        final sourceId = m['source_id'] as String?;
        final spotName = sourceType == 'post' && sourceId != null
            ? spotNameByPostId[sourceId]
            : null;

        events.add(
          ShadowPointEvent(
            id: id,
            giverUsername: displayName,
            spotName: spotName,
            points: pts,
            createdAt: createdAt,
          ),
        );
      }

      return events;
    } catch (e, st) {
      debugPrint('ShadowPointRepository.getRecentShadowEvents: $e\n$st');
      return [];
    }
  }

  Future<Map<String, String>> _fetchGiverUsernames(Set<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('users')
          .select('id, username')
          .inFilter('id', ids.toList());

      final list = rows as List<dynamic>? ?? const [];
      final map = <String, String>{};
      for (final r in list) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        final u = m['username'] as String?;
        if (id != null) map[id] = u ?? '';
      }
      return map;
    } catch (e, st) {
      debugPrint('ShadowPointRepository._fetchGiverUsernames: $e\n$st');
      return {};
    }
  }

  /// Post uuid → spot adı (RLS: gönderi ve mera görünürlüğü uygun olmalı).
  Future<Map<String, String>> _fetchSpotNamesForPosts(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('posts')
          .select('id, spot_id')
          .inFilter('id', postIds);

      final list = rows as List<dynamic>? ?? const [];
      final spotIds = <String>{};
      final postToSpot = <String, String>{};
      for (final r in list) {
        final m = r as Map<String, dynamic>;
        final pid = m['id'] as String?;
        final sid = m['spot_id'] as String?;
        if (pid != null && sid != null) {
          postToSpot[pid] = sid;
          spotIds.add(sid);
        }
      }

      if (spotIds.isEmpty) return {};

      final spots = await _client
          .from('fishing_spots')
          .select('id, name')
          .inFilter('id', spotIds.toList());

      final spotList = spots as List<dynamic>? ?? const [];
      final nameBySpotId = <String, String>{};
      for (final r in spotList) {
        final m = r as Map<String, dynamic>;
        final sid = m['id'] as String?;
        final name = m['name'] as String?;
        if (sid != null && name != null) nameBySpotId[sid] = name;
      }

      final out = <String, String>{};
      for (final e in postToSpot.entries) {
        final name = nameBySpotId[e.value];
        if (name != null) out[e.key] = name;
      }
      return out;
    } catch (e, st) {
      debugPrint('ShadowPointRepository._fetchSpotNamesForPosts: $e\n$st');
      return {};
    }
  }
}
