import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/models/fish_log_model.dart';
import 'package:balikci_app/data/repositories/fish_log_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

/// FishLogRepository provider.
final fishLogRepositoryProvider = Provider<FishLogRepository>((ref) {
  return FishLogRepository();
});

/// Giriş yapmış kullanıcının günlük kayıtları (remote + `local_fish_logs` önbellek).
final myFishLogsProvider = FutureProvider.autoDispose<List<FishLogModel>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final repo = ref.read(fishLogRepositoryProvider);
  return repo.getMyLogs(user.id);
});
