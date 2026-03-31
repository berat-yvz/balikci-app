import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/repositories/follow_repository.dart';

/// FollowRepository singleton provider.
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository();
});

/// Belirli bir kullanıcıyı şu anki kullanıcının takip edip etmediğini döner.
final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final repo = ref.watch(followRepositoryProvider);
  return repo.isFollowing(userId);
});

/// Takip / takipten çık işlemlerini yöneten AsyncNotifier.
class FollowNotifier extends AsyncNotifier<void> {
  late final FollowRepository _repo;

  @override
  void build() {
    _repo = ref.watch(followRepositoryProvider);
  }

  Future<void> follow(String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.follow(userId);
      // İlgili isFollowingProvider değerini tazele
      ref.invalidate(isFollowingProvider(userId));
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> unfollow(String userId) async {
    state = const AsyncLoading();
    try {
      await _repo.unfollow(userId);
      ref.invalidate(isFollowingProvider(userId));
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

final followNotifierProvider =
    AsyncNotifierProvider<FollowNotifier, void>(FollowNotifier.new);

