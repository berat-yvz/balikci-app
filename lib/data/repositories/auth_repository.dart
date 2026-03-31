import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/constants/oauth_constants.dart';
import 'package:balikci_app/core/services/supabase_service.dart';

/// Auth işlemleri için merkezi repository.
/// Supabase Auth üzerinden kayıt, giriş, çıkış ve oturum sorgularını yönetir.
/// Tüm hata mesajları Türkçe olarak fırlatılır.
///
/// `public.users` satırı tercihen sunucu tetikleyicisi ile oluşur
/// ([docs/supabase_fix_mera_insert.sql](docs/supabase_fix_mera_insert.sql) bölüm 1).
/// İstemcide [ensureUserProfile] yedek olarak kullanılır.
class AuthRepository {
  final _auth = SupabaseService.client.auth;
  final _db = SupabaseService.client;

  // ---------------------------------------------------------------------------
  // signUp — Kayıt ol (profil: tetikleyici + isteğe bağlı ensureUserProfile)
  // ---------------------------------------------------------------------------

  Future<AuthResponse> signUp(
    String email,
    String password,
    String username,
  ) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (response.session != null && response.user != null) {
        await ensureUserProfile(response.user!);
      }
      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // signIn — E-posta + şifre ile giriş yap
  // ---------------------------------------------------------------------------

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await ensureUserProfile(response.user!);
      }
      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // signInWithGoogle — OAuth (PKCE + deep link)
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithOAuth(OAuthProvider.google);
        return;
      }
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: OauthConstants.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // ensureUserProfile — public.users yoksa ekle (trigger yedeği)
  // ---------------------------------------------------------------------------

  Future<void> ensureUserProfile(User user) async {
    try {
      final existing = await _db
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) return;

      final email = user.email ?? '';
      final metaUser = user.userMetadata?['username'] as String?;
      var username = metaUser?.trim();
      if (username == null || username.isEmpty) {
        username = email.contains('@') ? email.split('@').first : 'user';
      }
      username = _sanitizeUsername(username);
      if (username.length < 3) username = 'user';
      final idShort = user.id.replaceAll('-', '');
      final suffix = idShort.length >= 8
          ? idShort.substring(0, 8)
          : idShort.padRight(8, '0');
      username = '${username}_$suffix';

      await _db.from('users').insert({
        'id': user.id,
        'email': email.isNotEmpty ? email : '$username@oauth.local',
        'username': username,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Zaten var, unique veya RLS — yutulur
    }
  }

  static String _sanitizeUsername(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (cleaned.isEmpty) return 'user';
    return cleaned.length > 16 ? cleaned.substring(0, 16) : cleaned;
  }

  // ---------------------------------------------------------------------------
  // signOut — Oturumu kapat
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Bağlantı hatası, lütfen tekrar deneyin');
    }
  }

  User? getCurrentUser() => _auth.currentUser;

  bool isLoggedIn() => _auth.currentUser != null;

  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: 'balikciapp://reset-callback/',
      );
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('invalid email') ||
          lower.contains('email address is invalid') ||
          lower.contains('unable to validate email')) {
        throw Exception('Geçerli bir e-posta adresi girin.');
      }
      if (lower.contains('user not found') ||
          lower.contains('email not found') ||
          lower.contains('no user')) {
        throw Exception('Bu e-posta ile kayıtlı hesap bulunamadı.');
      }
      throw Exception(
        'Şifre sıfırlama e-postası gönderilemedi. Tekrar deneyin.',
      );
    } catch (_) {
      throw Exception(
        'Şifre sıfırlama e-postası gönderilemedi. Tekrar deneyin.',
      );
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('email address is already used')) {
      return 'Bu email adresi zaten kullanımda';
    }

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('wrong password') ||
        lower.contains('email not confirmed')) {
      return 'Email veya şifre hatalı (veya e-posta henüz onaylanmadı)';
    }

    if (lower.contains('password should be at least') ||
        lower.contains('password is too short')) {
      return 'Şifre en az 6 karakter olmalı';
    }

    if (lower.contains('invalid email') ||
        lower.contains('unable to validate email') ||
        lower.contains('email address is invalid')) {
      return 'Geçersiz email adresi';
    }

    if (lower.contains('duplicate key') ||
        lower.contains('unique constraint')) {
      return 'Bu kullanıcı adı veya e-posta zaten kayıtlı';
    }

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return 'Bağlantı hatası, lütfen tekrar deneyin';
    }

    return message;
  }
}
