import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/data/repositories/favorite_repository.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';

/// FavoriteRepository singleton.
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository();
});

/// Giriş yapmış kullanıcının belirtilen mera (spotId) için favori durumunu döner.
/// Harita bottom sheet'indeki bookmark butonu tarafından izlenir.
final isFavoritedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, spotId) async {
  // Oturum değişince tekrar hesapla
  ref.watch(currentUserProvider);
  final repo = ref.read(favoriteRepositoryProvider);
  return repo.isFavorited(spotId);
});

/// Giriş yapmış kullanıcının tüm favori meralarını döner.
/// Profil sayfasındaki _FavoriteSpotsSection tarafından izlenir.
final favoriteSpotsProvider =
    FutureProvider.autoDispose<List<SpotModel>>((ref) async {
  ref.watch(currentUserProvider);
  final repo = ref.read(favoriteRepositoryProvider);
  return repo.getFavoriteSpots();
});
