import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/services/notification_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env dosyasını yükle (asset olarak bundle'a dahil)
  //    ARCHITECTURE.md → Güvenlik: API key asla hard-code edilmez.
  await dotenv.load(fileName: '.env');

  // 2. Firebase (FCM push bildirimleri vb. servisler için)
  await Firebase.initializeApp();

  // 3. Supabase başlat (.env'den URL + anon key okunur)
  await SupabaseService.initialize();

  // 4. Yerel veritabanı — Drift (offline-first)
  final _ = AppDatabase.instance;

  // 5. Push bildirim servisi (FCM + yerel bildirim kanalı)
  await NotificationService.initialize();

  // 6. SharedPreferences (Onboarding vs durumlar)
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // Riverpod ProviderScope tüm widget ağacını sarar
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BalikciApp(),
    ),
  );
}

class BalikciApp extends ConsumerWidget {
  const BalikciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Balıkçı App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
