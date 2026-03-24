import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client singleton.
/// ARCHITECTURE.md → Güvenlik Kuralları: API key asla client koduna yazılmaz.
/// URL ve anon key .env dosyasından okunur (flutter_dotenv ile).
///
/// Kullanım:
///   SupabaseService.client.from('table').select()
///   SupabaseService.auth.signInWithPassword(...)
class SupabaseService {
  SupabaseService._();

  /// .env'den okunan değerlerle Supabase'i başlatır.
  /// main() içinde, dotenv.load()'dan SONRA çağrılmalı.
  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    assert(url.isNotEmpty, '.env dosyasında SUPABASE_URL tanımlı değil!');
    assert(anonKey.isNotEmpty, '.env dosyasında SUPABASE_ANON_KEY tanımlı değil!');
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Supabase ayarları eksik. .env içinde SUPABASE_URL ve SUPABASE_ANON_KEY tanımlı olmalı.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Supabase veritabanı client'ı — sorgular için kullanılır.
  static SupabaseClient get client => Supabase.instance.client;

  /// Supabase Auth referansı — oturum işlemleri için kısayol.
  static GoTrueClient get auth => Supabase.instance.client.auth;

  /// Supabase Storage referansı — fotoğraf yükleme için kısayol.
  /// ARCHITECTURE.md: fish-photos bucket, max 2MB.
  static SupabaseStorageClient get storage => Supabase.instance.client.storage;

  /// Supabase Realtime referansı — anlık check-in güncellemeleri için.
  static RealtimeClient get realtime => Supabase.instance.client.realtime;
}
