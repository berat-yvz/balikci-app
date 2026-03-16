import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:balikci_app/core/constants/app_constants.dart';

/// Supabase client singleton.
/// Kullanım: `SupabaseService.client.from('table').select()`
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// main() içinde çağrılmalı, Supabase.initialize()'dan önce değil.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
}
