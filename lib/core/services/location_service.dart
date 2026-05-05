import 'package:geolocator/geolocator.dart';

enum LocationPurpose {
  checkin,   // 500m kural — en yüksek hassasiyet
  spotAdd,   // mera koordinatı — yüksek hassasiyet
  mapCenter, // harita merkezi — orta hassasiyet
  search,    // en yakın sıralama — düşük hassasiyet
  proximity, // oy diyaloğu — orta hassasiyet
}

/// Konum servisi wrapper.
/// geolocator paketini sarmalayarak izin yönetimini ve konum alma işlemini
/// tek yerden yönetir.
class LocationService {
  LocationService._();

  static LocationAccuracy _accuracyFor(LocationPurpose purpose) =>
      switch (purpose) {
        LocationPurpose.checkin   => LocationAccuracy.best,
        LocationPurpose.spotAdd   => LocationAccuracy.high,
        LocationPurpose.mapCenter => LocationAccuracy.medium,
        LocationPurpose.search    => LocationAccuracy.low,
        LocationPurpose.proximity => LocationAccuracy.medium,
      };

  /// Konum iznini kontrol eder; gerekirse ister.
  /// [purpose] senaryoya göre hassasiyet otomatik belirlenir.
  static Future<Position?> getCurrentPosition({
    LocationPurpose purpose = LocationPurpose.checkin,
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
      locationSettings: LocationSettings(accuracy: _accuracyFor(purpose)),
    );
  }

  /// Konum izni durumunu döner.
  static Future<LocationPermission> getPermissionStatus() =>
      Geolocator.checkPermission();

  /// Konum iznini ister.
  static Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
}
