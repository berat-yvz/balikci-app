/// EXIF okuma yardımcısı.
/// M-03 EXIF Doğrulama — native_exif paketi kullanılır.
/// Edge Function `exif-verify` bu verilerle doğrulama yapar.
///
/// NOT: Gerçek EXIF okuma, fotoğraf yükleme ekranında (H6) implemente edilecek.
/// Bu dosya placeholder + utility sınıfıdır.
class ExifHelper {
  ExifHelper._();

  /// EXIF GPS koordinatının mera konumuna ±1km içinde olup olmadığını kontrol eder.
  static bool isLocationValid({
    required double exifLat,
    required double exifLng,
    required double spotLat,
    required double spotLng,
    double radiusKm = 1.0,
  }) {
    final dist = _approxDistanceKm(exifLat, exifLng, spotLat, spotLng);
    return dist <= radiusKm;
  }

  /// EXIF timestamp'in şu andan ±30 dakika içinde olup olmadığını kontrol eder.
  static bool isTimestampValid(DateTime exifTime, {int toleranceMinutes = 30}) {
    final diff = DateTime.now().difference(exifTime).abs();
    return diff.inMinutes <= toleranceMinutes;
  }

  /// Basit Öklid yaklaşımı (kısa mesafeler için yeterli).
  static double _approxDistanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const degToKm = 111.0;
    final dLat = (lat1 - lat2) * degToKm;
    final dLng = (lng1 - lng2) * degToKm;
    return (dLat * dLat + dLng * dLng).abs();
  }
}
