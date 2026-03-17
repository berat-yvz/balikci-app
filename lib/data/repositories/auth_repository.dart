import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:balikci_app/core/services/supabase_service.dart';

/// Auth işlemleri için merkezi repository.
/// Supabase Auth üzerinden kayıt, giriş, çıkış ve oturum sorgularını yönetir.
/// Tüm hata mesajları Türkçe olarak fırlatılır.
class AuthRepository {
  final _auth = SupabaseService.client.auth;
  final _db = SupabaseService.client;

  // ---------------------------------------------------------------------------
  // signUp — Kayıt ol & users tablosuna profil ekle
  // ---------------------------------------------------------------------------

  /// [email] ve [password] ile Supabase Auth'a kayıt olur.
  /// Başarılıysa `users` tablosuna kullanıcı profilini (id, email, username,
  /// created_at) ekler.
  /// Hata durumunda Türkçe mesajla [AuthException] fırlatır.
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

      if (response.user != null) {
        // Kullanıcı profilini users tablosuna ekle
        await _db.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'username': username,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Bağlantı hatası, lütfen tekrar deneyin');
    }
  }

  // ---------------------------------------------------------------------------
  // signIn — E-posta + şifre ile giriş yap
  // ---------------------------------------------------------------------------

  /// [email] ve [password] ile Supabase Auth'a giriş yapar.
  /// Hata durumunda Türkçe mesajla [AuthException] fırlatır.
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Bağlantı hatası, lütfen tekrar deneyin');
    }
  }

  // ---------------------------------------------------------------------------
  // signOut — Oturumu kapat
  // ---------------------------------------------------------------------------

  /// Mevcut Supabase oturumunu kapatır.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Bağlantı hatası, lütfen tekrar deneyin');
    }
  }

  // ---------------------------------------------------------------------------
  // getCurrentUser — Mevcut kullanıcıyı döndür
  // ---------------------------------------------------------------------------

  /// Supabase oturumundaki mevcut [User] nesnesini döndürür.
  /// Giriş yapılmamışsa `null` döner.
  User? getCurrentUser() => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // isLoggedIn — Giriş durumu kontrolü
  // ---------------------------------------------------------------------------

  /// Kullanıcı oturum açmışsa `true`, açmamışsa `false` döner.
  bool isLoggedIn() => _auth.currentUser != null;

  // ---------------------------------------------------------------------------
  // _mapAuthError — Supabase hata mesajlarını Türkçeye çevir
  // ---------------------------------------------------------------------------

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
      return 'Email veya şifre hatalı';
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

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return 'Bağlantı hatası, lütfen tekrar deneyin';
    }

    // Eşleşmeyen hatalar için orijinal mesajı döndür
    return message;
  }
}
