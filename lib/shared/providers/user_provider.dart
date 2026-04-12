import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/core/constants/region_leaderboard_regions.dart';
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
  ref.watch(currentUserProvider);
  final repo = ref.read(userRepositoryProvider);
  return repo.getLeaderboard();
});

/// Rütbe filtresiyle liderlik (null = tümü).
final leaderboardFilteredProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String?>((ref, rankFilter) async {
      ref.watch(currentUserProvider);
      final repo = ref.read(userRepositoryProvider);
      return repo.getLeaderboard(rankFilter: rankFilter);
    });

/// Oturumdaki kullanıcının genel sıra numarası (1 tabanlı); giriş yoksa null.
final myLeaderboardRankProvider = FutureProvider.autoDispose<int?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.read(userRepositoryProvider);
  return repo.getMyLeaderboardRankPosition(user.id);
});

/// Toplulukta tüm kayıtlı balıkçılar (sıra limiti yok, alfabetik).
final allRegisteredAnglersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  ref.watch(currentUserProvider);
  final repo = ref.read(userRepositoryProvider);
  return repo.getAllRegisteredAnglers();
});

/// Kullanıcı adı araması (en az 2 karakter; kısa sorguda boş liste).
final userSearchByUsernameProvider =
    FutureProvider.autoDispose.family<List<UserModel>, String>((
  ref,
  query,
) async {
  final repo = ref.read(userRepositoryProvider);
  return repo.searchUsersByUsername(query: query);
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
  ref.watch(currentUserProvider);
  final repo = ref.read(userRepositoryProvider);
  return repo.getWeeklyLeaderboard();
});

/// Seçilen kıyı bölgesinde mera kaydı olan kullanıcılar (toplam puan).
final regionalLeaderboardProvider =
    FutureProvider.autoDispose.family<List<UserModel>, String>((
      ref,
      regionKey,
    ) async {
      ref.watch(currentUserProvider);
      CoastalLeaderboardRegion? box;
      for (final r in kCoastalLeaderboardRegions) {
        if (r.key == regionKey) {
          box = r;
          break;
        }
      }
      if (box == null) return const [];
      final repo = ref.read(userRepositoryProvider);
      return repo.getLeaderboardInCoastalBox(
        minLat: box.minLat,
        maxLat: box.maxLat,
        minLng: box.minLng,
        maxLng: box.maxLng,
      );
    });
