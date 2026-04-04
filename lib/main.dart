import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:balikci_app/app/router.dart';
import 'package:balikci_app/app/theme.dart';
import 'package:balikci_app/core/services/notification_service.dart';
import 'package:balikci_app/core/services/sync_service.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/data/local/database.dart';
import 'package:balikci_app/data/repositories/auth_repository.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final startupErrors = <String>[];

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    startupErrors.add(
      ".env yüklenemedi. Kök dizinde '.env' olduğundan ve pubspec.yaml assets'te listelendiğinden emin ol.\n$e",
    );
  }

  if (startupErrors.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      startupErrors.add(
        "Firebase başlatılamadı (genelde android/app/google-services.json eksik).\n$e",
      );
    }
  }

  if (startupErrors.isEmpty) {
    try {
      await SupabaseService.initialize();
    } catch (e) {
      startupErrors.add(
        "Supabase başlatılamadı (.env: SUPABASE_URL, SUPABASE_ANON_KEY).\n$e",
      );
    }
  }

  if (startupErrors.isEmpty) {
    try {
      final _ = AppDatabase.instance;
      SyncService(AppDatabase.instance).startListening();
    } catch (e) {
      startupErrors.add("Yerel veritabanı başlatılamadı.\n$e");
    }
  }

  if (startupErrors.isEmpty) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      startupErrors.add("Bildirim servisi başlatılamadı.\n$e");
    }
  }

  if (startupErrors.isEmpty) {
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        unawaited(AuthRepository().ensureUserProfile(user));
      }
    });

    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) async {
      await SupabaseService.client.auth.getSessionFromUrl(uri);
    });
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        await SupabaseService.client.auth.getSessionFromUrl(initial);
      }
    } catch (e) {
      debugPrint('App link oturumu açılamadı: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: startupErrors.isEmpty
          ? const BalikciApp()
          : StartupErrorApp(errors: startupErrors),
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

class StartupErrorApp extends StatelessWidget {
  final List<String> errors;
  const StartupErrorApp({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: StartupErrorScreen(errors: errors),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final List<String> errors;
  const StartupErrorScreen({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başlatma hatası')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Uygulama başlatılamadı. Aşağıdakileri düzeltip yeniden çalıştırın.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
