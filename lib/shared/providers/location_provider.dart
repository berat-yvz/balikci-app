import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:balikci_app/core/services/location_service.dart';

/// Mevcut konum provider — harita ve check-in ekranları kullanır.
final locationProvider = FutureProvider<Position?>((ref) async {
  return LocationService.getCurrentPosition();
});

/// Konum izni durumu
final locationPermissionProvider =
    FutureProvider<LocationPermission>((ref) async {
  return LocationService.getPermissionStatus();
});
