/// Bildirimden veya derin bağlantıdan meraya gidildiğinde
/// [ProximityVoteService] ile aynı anda oylama diyaloğunun açılmasını önler.
class LaunchNavigationSuppression {
  LaunchNavigationSuppression._();

  static DateTime? _proximityVoteSuppressedUntil;

  /// Harita hedef mera ile açılırken otomatik yakınlık oylamasını geçici kapatır.
  static void suppressProximityVoteBriefly({
    Duration duration = const Duration(seconds: 90),
  }) {
    _proximityVoteSuppressedUntil = DateTime.now().add(duration);
  }

  static bool get shouldSkipProximityVoteDialog {
    final until = _proximityVoteSuppressedUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _proximityVoteSuppressedUntil = null;
      return false;
    }
    return true;
  }
}
