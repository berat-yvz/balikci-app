/// Puan hesaplama yardımcıları.
/// M-06 Puan, Rütbe & Motivasyon — MVP_PLAN.md referans.
class ScoreUtils {
  ScoreUtils._();

  // Puan tablosu
  static const int spotPublicShare = 50;
  static const int checkinVerified = 30;
  static const int checkinUnverified = 15;
  static const int correctVoteReceived = 10;
  static const int shadowPoint = 20;
  static const int releaseWithExif = 40;
  static const int dailyLogPublic = 10;
  static const int wrongReportPenalty = -20;

  // Rütbe eşikleri
  static const int rankOltaKurdu = 500;
  static const int rankUsta = 2000;
  static const int rankDenizReisi = 5000;

  /// Toplam puana göre rütbe stringi döner.
  static String rankFromScore(int score) {
    if (score >= rankDenizReisi) return 'deniz_reisi';
    if (score >= rankUsta) return 'usta';
    if (score >= rankOltaKurdu) return 'olta_kurdu';
    return 'acemi';
  }

  /// Rütbe emoji döner.
  static String rankEmoji(String rank) {
    switch (rank) {
      case 'deniz_reisi':
        return '🌊';
      case 'usta':
        return '⚓';
      case 'olta_kurdu':
        return '🎣';
      default:
        return '🪝';
    }
  }

  /// Kullanıcı bir sonraki rütbeye kaç puan uzakta?
  static int pointsToNextRank(int score) {
    if (score < rankOltaKurdu) return rankOltaKurdu - score;
    if (score < rankUsta) return rankUsta - score;
    if (score < rankDenizReisi) return rankDenizReisi - score;
    return 0; // Zaten max rütbe
  }
}
