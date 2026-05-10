import 'package:flutter/foundation.dart';

import 'package:balikci_app/core/services/supabase_service.dart';

/// Puan kaynağı tipleri — score-calculator Edge Function ile birebir uyumlu.
enum ScoreSource {
  checkinUnverified('checkin_unverified'), // +15
  correctVote('correct_vote'), // +10
  wrongReport('wrong_report'), // -20
  spotPublic('spot_public'), // +50
  spotFriends('spot_friends'), // +30
  spotPrivate('spot_private'), // +10
  postShared('post_share'), // +20
  postLiked('post_liked'), // +5
  postComment('post_comment'); // +2

  const ScoreSource(this.value);
  final String value;
}

/// Supabase `score-calculator` Edge Function'ı çağıran servis.
///
/// Hata durumunda sessizce devam eder — skor güncelleme ana iş akışını
/// engellememelidir.
class ScoreService {
  ScoreService._();

  /// [userId] kullanıcısının [source] kaynağından puan kazanmasını tetikler.
  ///
  /// [extraFields] — `source_id`, `spot_id`, `post_id`, `liker_id` vb. edge doğrulaması için.
  ///
  /// Fire-and-forget: beklenmeden çağrılabilir.
  static Future<void> award(
    String userId,
    ScoreSource source, {
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'source_type': source.value,
      };
      if (extraFields != null) {
        for (final e in extraFields.entries) {
          if (e.value != null) body[e.key] = e.value;
        }
      }
      await SupabaseService.client.functions.invoke(
        'score-calculator',
        body: body,
      );
    } catch (e) {
      // Puan güncellemesi başarısız olsa bile ana akış devam eder.
      debugPrint('[ScoreService] award failed: $e');
    }
  }
}
