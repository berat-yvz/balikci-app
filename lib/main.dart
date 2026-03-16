import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/services/notification_service.dart';
import 'package:balikci_app/data/local/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env dosyasını yükle (asset olarak bundle'a dahil)
  //    ARCHITECTURE.md → Güvenlik: API key asla hard-code edilmez.
  await dotenv.load(fileName: '.env');

  // 2. Supabase başlat (.env'den URL + anon key okunur)
  await SupabaseService.initialize();

  // 3. Firebase (FCM push bildirimleri için)
  await Firebase.initializeApp();

  // 4. Yerel veritabanı — Isar (offline-first)
  await IsarService.initialize();

  // 5. Push bildirim servisi (FCM + yerel bildirim kanalı)
  await NotificationService.initialize();

  runApp(
    // Riverpod ProviderScope tüm widget ağacını sarar
    const ProviderScope(
      child: BalikciApp(),
    ),
  );
}

class BalikciApp extends StatelessWidget {
  const BalikciApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Balıkçı App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
