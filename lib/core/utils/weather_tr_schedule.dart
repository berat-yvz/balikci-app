/// Türkiye sabit UTC+3 (yaz-kış saati yok).
/// Sonraki İstanbul yerel **XX:02:00** anına karşılık gelen UTC anı.
///
/// Sunucu pg_cron ile saat başında `weather-cache` çalıştırır; istemci veriyi
/// bundan ~2 dk sonra okur (işlem bitsin diye).
DateTime nextUtcInstantForIstanbulWallMinute2(DateTime utcNow) {
  final u = utcNow.toUtc();
  final tr = u.add(const Duration(hours: 3));
  var cand = DateTime.utc(tr.year, tr.month, tr.day, tr.hour, 2, 0)
      .subtract(const Duration(hours: 3));
  if (!cand.isAfter(u)) {
    cand = cand.add(const Duration(hours: 1));
  }
  return cand;
}

/// İstanbul duvar saatinde bu saat diliminde **02. dakikadan itibaren** miyiz?
/// Planlı `weather_cache` okumasını saat başı cron bittikten sonra yapmak için.
bool isIstanbulWallMinuteAtOrAfterSyncMark(DateTime utcNow) {
  final tr = utcNow.toUtc().add(const Duration(hours: 3));
  return tr.minute >= 2;
}

/// Open-Meteo `timezone=Europe/Istanbul` ile dönen `2026-05-08T13:00` gibi
/// ofsetsiz dizeleri UTC'ye çevirir (TR sabit +03:00).
DateTime openMeteoIstanbulNaiveTimeToUtc(String timeStr) {
  var s = timeStr.trim();
  if (s.contains(' ') && !s.contains('T')) {
    s = s.replaceFirst(' ', 'T');
  }
  if (s.endsWith('Z') || s.endsWith('z')) {
    return DateTime.parse(s).toUtc();
  }
  final tIdx = s.indexOf('T');
  final tail = tIdx >= 0 ? s.substring(tIdx + 1) : s;
  if (RegExp(r'[+-]\d{2}').hasMatch(tail)) {
    return DateTime.parse(s).toUtc();
  }
  return DateTime.parse('$s+03:00').toUtc();
}

/// Şu anki İstanbul yerel saat dilimine göre "bu saatin başı" anı (UTC).
/// Saatlik slot filtreleri cihaz yerel saatine bağlı kalmaz.
DateTime startOfCurrentIstanbulWallHourUtc(DateTime utcNow) {
  final tr = utcNow.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(tr.year, tr.month, tr.day, tr.hour, 0, 0)
      .subtract(const Duration(hours: 3));
}

/// Verilen anın İstanbul duvar takvimindeki günü (yerel yıl-ay-gün).
DateTime istanbulWallDateOnlyFromUtc(DateTime utcInstant) {
  final tr = utcInstant.toUtc().add(const Duration(hours: 3));
  return DateTime(tr.year, tr.month, tr.day);
}

/// Verilen UTC anının İstanbul yerel saat (0–23).
int istanbulWallHourFromUtc(DateTime utcInstant) {
  final tr = utcInstant.toUtc().add(const Duration(hours: 3));
  return tr.hour;
}
