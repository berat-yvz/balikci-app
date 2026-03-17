import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';

// Features — Auth
import 'package:balikci_app/features/auth/splash_screen.dart';
import 'package:balikci_app/features/auth/login_screen.dart';
import 'package:balikci_app/features/auth/register_screen.dart';
import 'package:balikci_app/features/auth/onboarding/onboarding_screen.dart';

// Features — Home Shell
import 'package:balikci_app/features/main_shell.dart';

// Features — Map
import 'package:balikci_app/features/map/map_screen.dart';
import 'package:balikci_app/features/map/add_spot_screen.dart';

// Features — Check-in
import 'package:balikci_app/features/checkin/checkin_screen.dart';

// Features — Fish Log
import 'package:balikci_app/features/fish_log/log_list_screen.dart';
import 'package:balikci_app/features/fish_log/add_log_screen.dart';
import 'package:balikci_app/features/fish_log/stats_screen.dart';

// Features — Rank
import 'package:balikci_app/features/rank/rank_screen.dart';
import 'package:balikci_app/features/rank/leaderboard_screen.dart';

// Features — Knots
import 'package:balikci_app/features/knots/knots_screen.dart';
import 'package:balikci_app/features/knots/knot_detail_screen.dart';

// Features — Weather
import 'package:balikci_app/features/weather/weather_screen.dart';

// Features — Notifications
import 'package:balikci_app/features/notifications/notification_list_screen.dart';
import 'package:balikci_app/features/notifications/notification_settings_screen.dart';

// Features — Profile
import 'package:balikci_app/features/profile/profile_screen.dart';
import 'package:balikci_app/features/profile/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final isOnboardingCompleted = ref.watch(onboardingStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authRepo.isLoggedIn();
      final path = state.uri.path;

      // Splash için kontrol yok
      if (path == '/splash') return null;

      final isLoginOrRegister = path == '/login' || path == '/register';

      // 1. Durum: Kullanıcı giriş yapmamış
      if (!isLoggedIn) {
        if (!isLoginOrRegister) {
          // Giriş yapmamış kişi korumalı ya da onboarding sayfasına gidemez
          return '/login';
        }
        return null;
      }

      // 2. Durum: Kullanıcı giriş YAPMIŞ

      // Eğer yetkilendirme ekranlarına (/login, /register) gitmek isterse:
      if (isLoginOrRegister) {
        return isOnboardingCompleted ? '/home' : '/onboarding';
      }

      // Onboarding tamamlanmamışsa VE başka (korumalı) bir yere gitmeye çalışıyorsa:
      if (!isOnboardingCompleted && path != '/onboarding') {
        return '/onboarding';
      }

      // Onboarding TAMAMLANMIŞSA VE zorla onboarding'e gitmek istiyorsa:
      if (isOnboardingCompleted && path == '/onboarding') {
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),

      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),

      // Home (Şimdilik boş Scaffold)
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),

      // Map (ana ekran)
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/map/add-spot', builder: (context, state) => const AddSpotScreen()),

      // Check-in
      GoRoute(
        path: '/checkin/:spotId',
        builder: (_, state) =>
            CheckinScreen(spotId: state.pathParameters['spotId']!),
      ),

      // Fish Log
      GoRoute(path: '/logs', builder: (context, state) => const LogListScreen()),
      GoRoute(path: '/logs/add', builder: (context, state) => const AddLogScreen()),
      GoRoute(path: '/logs/stats', builder: (context, state) => const StatsScreen()),

      // Rank
      GoRoute(path: '/rank', builder: (context, state) => const RankScreen()),
      GoRoute(
          path: '/rank/leaderboard',
          builder: (context, state) => const LeaderboardScreen()),

      // Knots
      GoRoute(path: '/knots', builder: (context, state) => const KnotsScreen()),
      GoRoute(
        path: '/knots/:knotId',
        builder: (_, state) =>
            KnotDetailScreen(knotId: state.pathParameters['knotId']!),
      ),

      // Weather
      GoRoute(path: '/weather', builder: (context, state) => const WeatherScreen()),

      // Notifications
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationListScreen()),
      GoRoute(
          path: '/notifications/settings',
          builder: (context, state) => const NotificationSettingsScreen()),

      // Profile
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: '/profile/settings', builder: (context, state) => const SettingsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
    ),
  );
});
