import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/data/repositories/user_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

export 'package:balikci_app/data/repositories/user_repository.dart'
    show WeeklyRankEntry;

// cleaned: provider yaşam döngüsü optimize edildi ve dokümantasyon netleştirildi

/// UserRepository singleton provider.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Geçerli oturumdaki kullanıcının profilini dönen FutureProvider.
final currentUserProfileProvider = FutureProvider.autoDispose<UserModel?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repo = ref.read(userRepositoryProvider);
  return repo.getProfile(user.id);
});

/// Genel liderlik tablosu provider'ı.
final leaderboardProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final repo = ref.read(userRepositoryProvider);
  // İleride bölge filtresi preferences üzerinden eklenebilir.
  return repo.getLeaderboard();
});

/// Belirli bir kullanıcının profilini dönen provider.
final userProfileProvider = FutureProvider.autoDispose
    .family<UserModel?, String>((ref, userId) async {
      final repo = ref.read(userRepositoryProvider);
      return repo.getProfile(userId);
    });

/// Haftalık check-in aktivitesine göre sıralama.
final weeklyLeaderboardProvider =
    FutureProvider.autoDispose<List<WeeklyRankEntry>>((ref) async {
  final repo = ref.read(userRepositoryProvider);
  return repo.getWeeklyLeaderboard();
});
