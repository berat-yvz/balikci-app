import 'package:flutter/foundation.dart';

import 'package:balikci_app/core/services/supabase_service.dart';

/// Puan kaynağı tipleri — score-calculator Edge Function ile birebir uyumlu.
enum ScoreSource {
  checkinVerified('checkin_verified'),     // +30
  checkinUnverified('checkin_unverified'), // +15
  correctVote('correct_vote'),             // +10 (olumlu oy alanı)
  wrongReport('wrong_report'),             // -20 (yanlış bildirim oylaması)
  fishLogPublic('fish_log_public'),        // +10
  releaseExif('release_exif'),             // +40 (EXIF doğrulamalı salma)
  spotPublic('spot_public');               // +50

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
  /// Fire-and-forget: beklenmeden çağrılabilir.
  static Future<void> award(String userId, ScoreSource source) async {
    try {
      await SupabaseService.client.functions.invoke(
        'score-calculator',
        body: {'user_id': userId, 'source_type': source.value},
      );
    } catch (e) {
      // Puan güncellemesi başarısız olsa bile ana akış devam eder.
      debugPrint('[ScoreService] award failed: $e');
    }
  }
}
