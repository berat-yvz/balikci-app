/// Türkiye sabit UTC+3 (yaz-kış saati yok).
/// Sonraki İstanbul yerel **XX:02:00** anına karşılık gelen UTC anı.
///
/// Sunucu pg_cron ile saat başında `weather-cache` çalıştırır; istemci veriyi
/// bundan ~2 dk sonra okur (işlem bitsin diye).
DateTime nextUtcInstantForIstanbulWallMinute2(DateTime utcNow) {
  final tr = utcNow.add(const Duration(hours: 3));
  var cand = DateTime.utc(tr.year, tr.month, tr.day, tr.hour, 2, 0)
      .subtract(const Duration(hours: 3));
  if (!cand.isAfter(utcNow)) {
    cand = cand.add(const Duration(hours: 1));
  }
  return cand;
}
