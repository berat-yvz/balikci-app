import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/services/sync_service.dart';

/// Offline sync servis provider'ı — SyncService singleton'ını expose eder.
final syncServiceProvider = Provider<SyncService>((ref) {
  ref.onDispose(SyncService.instance.dispose);
  return SyncService.instance;
});
