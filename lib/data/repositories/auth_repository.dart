import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/models/user_model.dart';

/// Auth repository — Supabase Auth wrapper.
/// H2 sprint görevleri: signUp, signIn, signOut, getUser
class AuthRepository {
  final _auth = SupabaseService.client.auth;
  final _db = SupabaseService.client;

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (response.user == null) return null;
    // Kullanıcı profilini users tablosuna ekle
    await _db.from('users').insert({
      'id': response.user!.id,
      'email': email,
      'username': username,
    });
    return getUser(response.user!.id);
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) return null;
    return getUser(response.user!.id);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> getUser(String userId) async {
    try {
      final data =
          await _db.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  UserModel? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Profil verisi için getUser() çağrılmalı; bu sadece auth session
    return null;
  }

  bool get isLoggedIn => _auth.currentUser != null;
}
