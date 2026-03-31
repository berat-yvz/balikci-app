import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/sync_service.dart';
import 'package:balikci_app/data/local/database.dart';

/// Offline sync servis provider'ı.
final syncServiceProvider = Provider<SyncService>((ref) {
  // cleaned: SyncService provider entegrasyonu eklendi
  final service = SyncService(AppDatabase.instance);
  ref.onDispose(service.dispose);
  return service;
});
