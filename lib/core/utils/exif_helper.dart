import 'package:native_exif/native_exif.dart';

/// EXIF okuma helper'ı.
///
/// Bu sınıf, check-in fotoğrafından:
/// - GPS konumu (GPSLatitude/GPSLongitude)
/// - timestamp (DateTimeOriginal)
/// verilerini okur ve app içi doğrulama için utility fonksiyonları sağlar.
class ExifGpsTimestamp {
  final double latitude;
  final double longitude;
  final DateTime originalDate;

  const ExifGpsTimestamp({
    required this.latitude,
    required this.longitude,
    required this.originalDate,
  });
}

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

  /// Fotoğraf dosya yolundan EXIF GPS + timestamp okur.
  ///
  /// EXIF alanları eksikse `null` döner.
  static Future<ExifGpsTimestamp?> readGpsAndTimestampFromPath(
    String imagePath,
  ) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      try {
        final latLong = await exif.getLatLong();
        final originalDate = await exif.getOriginalDate();
        if (latLong == null || originalDate == null) return null;

        return ExifGpsTimestamp(
          latitude: latLong.latitude,
          longitude: latLong.longitude,
          originalDate: originalDate,
        );
      } finally {
        // native_exif belleği temizlemek için close öneriyor.
        await exif.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Fotoğraf dosyasından okunan EXIF bilgisini:
  /// - GPS: ±[radiusKm]
  /// - timestamp: ±[toleranceMinutes]
  /// kriterlerine göre doğrular.
  static Future<bool> validateExifFromPath({
    required String imagePath,
    required double spotLat,
    required double spotLng,
    double radiusKm = 1.0,
    int toleranceMinutes = 30,
  }) async {
    final data = await readGpsAndTimestampFromPath(imagePath);
    if (data == null) return false;

    final locationOk = isLocationValid(
      exifLat: data.latitude,
      exifLng: data.longitude,
      spotLat: spotLat,
      spotLng: spotLng,
      radiusKm: radiusKm,
    );
    final timestampOk = isTimestampValid(
      data.originalDate,
      toleranceMinutes: toleranceMinutes,
    );

    return locationOk && timestampOk;
  }

  /// Basit Öklid yaklaşımı (kısa mesafeler için yeterli).
  static double _approxDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const degToKm = 111.0;
    final dLat = (lat1 - lat2) * degToKm;
    final dLng = (lng1 - lng2) * degToKm;
    return (dLat * dLat + dLng * dLng).abs();
  }
}
