import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Features — Auth
import 'package:balikci_app/features/auth/login_screen.dart';
import 'package:balikci_app/features/auth/register_screen.dart';
import 'package:balikci_app/features/auth/onboarding/onboarding_screen.dart';

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

final appRouter = GoRouter(
  initialLocation: '/map',
  // TODO: H2 - redirect guard eklenecek (auth_provider ile)
  // redirect: (context, state) { ... },
  routes: [
    // Auth
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

    // Map (ana ekran)
    GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
    GoRoute(path: '/map/add-spot', builder: (_, __) => const AddSpotScreen()),

    // Check-in
    GoRoute(
      path: '/checkin/:spotId',
      builder: (_, state) =>
          CheckinScreen(spotId: state.pathParameters['spotId']!),
    ),

    // Fish Log
    GoRoute(path: '/logs', builder: (_, __) => const LogListScreen()),
    GoRoute(path: '/logs/add', builder: (_, __) => const AddLogScreen()),
    GoRoute(path: '/logs/stats', builder: (_, __) => const StatsScreen()),

    // Rank
    GoRoute(path: '/rank', builder: (_, __) => const RankScreen()),
    GoRoute(
        path: '/rank/leaderboard',
        builder: (_, __) => const LeaderboardScreen()),

    // Knots
    GoRoute(path: '/knots', builder: (_, __) => const KnotsScreen()),
    GoRoute(
      path: '/knots/:knotId',
      builder: (_, state) =>
          KnotDetailScreen(knotId: state.pathParameters['knotId']!),
    ),

    // Weather
    GoRoute(path: '/weather', builder: (_, __) => const WeatherScreen()),

    // Notifications
    GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationListScreen()),
    GoRoute(
        path: '/notifications/settings',
        builder: (_, __) => const NotificationSettingsScreen()),

    // Profile
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(
        path: '/profile/settings', builder: (_, __) => const SettingsScreen()),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Sayfa bulunamadı: ${state.uri}')),
  ),
);
