import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gerçek ağ bağlantısı durumu — H12 connectivity_plus ile implemente edildi.
///
/// `true` → en az bir bağlantı türü aktif (wifi, mobile, ethernet)
/// `false` → çevrimdışı (none)
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

/// Anlık bağlantı durumu — widget'larda `ref.watch` ile kullan.
/// `true` → online, `false` → offline
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).asData?.value ?? true;
});
