import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Arka planda alınan GPS konumu; null iken harita İstanbul varsayılanını kullanır.
final userLocationProvider = StateProvider<Position?>((ref) => null);
