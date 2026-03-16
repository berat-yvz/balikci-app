import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/core/services/notification_service.dart';
import 'package:balikci_app/data/local/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase başlatma (URL ve key --dart-define ile geliyor)
  await SupabaseService.initialize();

  // Firebase (FCM için)
  await Firebase.initializeApp();

  // Yerel veritabanı (Isar — offline-first)
  await IsarService.initialize();

  // Push bildirim servisi
  await NotificationService.initialize();

  runApp(
    // Riverpod ProviderScope tüm ağacı sarar
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
