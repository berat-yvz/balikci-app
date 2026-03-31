import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/models/user_model.dart';
import 'package:balikci_app/data/repositories/user_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

/// UserRepository singleton provider.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Geçerli oturumdaki kullanıcının profilini dönen FutureProvider.
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfile(user.id);
});

/// Genel liderlik tablosu provider'ı.
final leaderboardProvider =
    FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  // İleride bölge filtresi preferences üzerinden eklenebilir.
  return repo.getLeaderboard();
});

/// Belirli bir kullanıcının profilini dönen provider.
final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfile(userId);
});

