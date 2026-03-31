import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/repositories/auth_repository.dart';

// -----------------------------------------------------------------------------
// 1. authRepositoryProvider
// -----------------------------------------------------------------------------

/// [AuthRepository]'nin singleton örneğini sağlayan provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// -----------------------------------------------------------------------------
// 2. authStateProvider
// -----------------------------------------------------------------------------

/// Supabase'in anlık oturum (auth state) değişimlerini dinleyen stream provider.
/// Uygulama açıkken giriş/çıkış durumlarını anında UI'a yansıtır.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

// -----------------------------------------------------------------------------
// 3. currentUserProvider
// -----------------------------------------------------------------------------

/// Supabase oturumundaki mevcut [User] nesnesini (varsa) sağlayan provider.
/// Auth state değişimlerinde otomatik olarak yeniden hesaplanmazsa diye,
/// UI anlık güncellemeleri için `authStateProvider`'ın değeri de izlenebilir.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getCurrentUser();
});

// -----------------------------------------------------------------------------
// 4. isLoggedInProvider
// -----------------------------------------------------------------------------

/// Kullanıcının giriş yapıp yapmadığını belirten boolean provider.
final isLoggedInProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.isLoggedIn();
});

// -----------------------------------------------------------------------------
// 5. authNotifierProvider
// -----------------------------------------------------------------------------

/// Kullanıcı giriş, kayıt ve çıkış işlemlerini yöneten asenkron notifier.
/// İşlem sırasında `loading` durumunu UI'a bildirir. Hata olursa `error` state'ine geçer.
class AuthNotifier extends AsyncNotifier<User?> {
  late final AuthRepository _authRepository;

  @override
  FutureOr<User?> build() {
    _authRepository = ref.watch(authRepositoryProvider);
    return _authRepository.getCurrentUser();
  }

  /// E-posta ve şifre ile giriş yapar.
  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading(); // Yükleme durumunu başlat
    try {
      final response = await _authRepository.signIn(email, password);
      final user = response.user;
      state = AsyncData(user); // Başarılıysa kullanıcıyı state'e yaz
    } catch (e, stackTrace) {
      if (e is AuthException) {
        state = AsyncError(
          e.message,
          stackTrace,
        ); // AuthException ise mesajı doğrudan al
      } else {
        state = AsyncError(e.toString(), stackTrace); // Diğer hatalar
      }
    }
  }

  /// E-posta, şifre ve kullanıcı adı ile yeni bir hesap oluşturur.
  Future<void> signUp(String email, String password, String username) async {
    state = const AsyncLoading(); // Yükleme durumunu başlat
    try {
      final response = await _authRepository.signUp(email, password, username);
      final user = response.user;
      state = AsyncData(user); // Başarılıysa kullanıcıyı state'e yaz
    } catch (e, stackTrace) {
      if (e is AuthException) {
        state = AsyncError(e.message, stackTrace);
      } else {
        state = AsyncError(e.toString(), stackTrace);
      }
    }
  }

  /// Oturumu kapatır.
  Future<void> signOut() async {
    state = const AsyncLoading(); // Yükleme durumunu başlat
    try {
      await _authRepository.signOut();
      state = const AsyncData(null); // Çıkış başarılıysa state'i null yap
    } catch (e, stackTrace) {
      if (e is AuthException) {
        state = AsyncError(e.message, stackTrace);
      } else {
        state = AsyncError(e.toString(), stackTrace);
      }
    }
  }

  /// Google ile giriş — tarayıcı / sistem UI; oturum deep link ile tamamlanır.
  Future<void> signInWithGoogle() async {
    try {
      await _authRepository.signInWithGoogle();
      state = AsyncData(_authRepository.getCurrentUser());
    } catch (e, stackTrace) {
      if (e is AuthException) {
        state = AsyncError(e.message, stackTrace);
      } else {
        state = AsyncError(e.toString(), stackTrace);
      }
    }
  }
}

/// [AuthNotifier] state'ini ve metodlarını UI'a bağlamak için kullanılan provider.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
