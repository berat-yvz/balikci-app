import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:balikci_app/data/repositories/auth_repository.dart';
import 'package:balikci_app/data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Mevcut kullanıcı durumu — oturum açık/kapalı
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // TODO: H2 — Isar'dan token kontrolü ve mevcut session yükleme
    state = const AsyncValue.data(null);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signIn(email: email, password: password),
    );
  }

  Future<void> signUp(String email, String password, String username) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signUp(email: email, password: password, username: username),
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }
}
