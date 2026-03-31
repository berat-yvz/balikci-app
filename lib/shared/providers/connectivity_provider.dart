import 'package:flutter_riverpod/flutter_riverpod.dart';

// cleaned: placeholder korunarak minimum stabil stream davranışı belgelendi

/// Ağ bağlantısı durumu provider.
/// H12 sprint'te connectivity_plus ile gerçek implementation yapılacak.
/// Şimdilik placeholder olarak online kabul edilir.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  // TODO: H12 — connectivity_plus paketi ile gerçek bağlantı izleme
  yield true; // varsayılan: online
});
