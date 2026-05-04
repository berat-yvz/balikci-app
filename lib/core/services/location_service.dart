import 'package:geolocator/geolocator.dart';

/// Konum servisi wrapper.
/// geolocator paketini sarmalayarak izin yönetimini ve konum alma işlemini
/// tek yerden yönetir.
class LocationService {
  LocationService._();

  /// Konum iznini kontrol eder; gerekirse ister.
  /// [accuracy] senaryoya göre verilir — varsayılan medium (bölge düzeyi).
  /// Kritik senaryolar (check-in, mera koordinatı) için high/best kullanın.
  static Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  /// Konum izni durumunu döner.
  static Future<LocationPermission> getPermissionStatus() =>
      Geolocator.checkPermission();

  /// Konum iznini ister.
  static Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
}
