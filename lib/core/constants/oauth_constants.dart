/// Google OAuth deep link — Supabase Dashboard Redirect URLs ile aynı olmalı.
class OauthConstants {
  OauthConstants._();

  static const scheme = 'balikciapp';
  static const host = 'login-callback';

  static String get redirectUrl => '$scheme://$host/';
}
