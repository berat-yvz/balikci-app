import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:balikci_app/app/app_routes.dart';
import 'package:balikci_app/app/go_router_refresh.dart';
import 'package:balikci_app/data/models/spot_model.dart';
import 'package:balikci_app/core/services/supabase_service.dart';
import 'package:balikci_app/shared/providers/auth_provider.dart';
import 'package:balikci_app/shared/providers/preferences_provider.dart';

// Core Widgets
import 'package:balikci_app/core/widgets/splash_screen.dart';

// Features — Auth
import 'package:balikci_app/features/auth/login_screen.dart';
import 'package:balikci_app/features/auth/register_screen.dart';
import 'package:balikci_app/features/auth/reset_password_screen.dart';
import 'package:balikci_app/features/auth/onboarding/onboarding_screen.dart';

// Features — Home Shell
import 'package:balikci_app/features/main_shell.dart';

// Features — Map
import 'package:balikci_app/features/map/map_screen.dart';
import 'package:balikci_app/features/map/add_spot_screen.dart';
import 'package:balikci_app/features/map/pick_spot_location_screen.dart';

// Features — Check-in
import 'package:balikci_app/features/checkin/checkin_screen.dart';

// Features — Fish Log
import 'package:balikci_app/features/fish_log/screens/log_list_screen.dart';
import 'package:balikci_app/features/fish_log/screens/add_log_screen.dart';
import 'package:balikci_app/features/fish_log/stats_screen.dart';

// Features — Rank
import 'package:balikci_app/features/rank/rank_screen.dart';
import 'package:balikci_app/features/rank/leaderboard_screen.dart';

// Features — Knots
import 'package:balikci_app/features/knots/knots_screen.dart';
import 'package:balikci_app/features/knots/knot_detail_screen.dart';
import 'package:balikci_app/data/models/knot_model.dart';

// Features — Weather
import 'package:balikci_app/features/weather/weather_screen.dart';

// Features — Notifications
import 'package:balikci_app/features/notifications/notification_list_screen.dart';
import 'package:balikci_app/features/notifications/notification_settings_screen.dart';

// Features — Profile
import 'package:balikci_app/features/profile/profile_screen.dart';
import 'package:balikci_app/features/profile/settings_screen.dart';

/// Bildirim yönlendirme ve genel navigasyon için global key.
/// NotificationService bu key üzerinden GoRouter.of(context).go() çağırır.
final appNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final isOnboardingCompleted = ref.watch(onboardingStateProvider);

  final refresh = GoRouterRefreshStream(
    SupabaseService.client.auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: appNavigatorKey,
    refreshListenable: refresh,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoggedIn = authRepo.isLoggedIn();
      final path = state.uri.path;

      // Splash için kontrol yok
      if (path == AppRoutes.splash) return null;

      final isAuthFlow =
          path == AppRoutes.login ||
          path == AppRoutes.register ||
          path == AppRoutes.resetCallback;

      // 1. Durum: Kullanıcı giriş yapmamış
      if (!isLoggedIn) {
        if (!isAuthFlow) {
          // Giriş yapmamış kişi korumalı ya da onboarding sayfasına gidemez
          return AppRoutes.login;
        }
        return null;
      }

      // 2. Durum: Kullanıcı giriş YAPMIŞ

      // Eğer yetkilendirme ekranlarına (/login, /register) gitmek isterse:
      if (isAuthFlow) {
        return isOnboardingCompleted ? AppRoutes.home : AppRoutes.onboarding;
      }

      // Onboarding tamamlanmamışsa VE başka (korumalı) bir yere gitmeye çalışıyorsa:
      if (!isOnboardingCompleted && path != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      // Onboarding TAMAMLANMIŞSA VE zorla onboarding'e gitmek istiyorsa:
      if (isOnboardingCompleted && path == AppRoutes.onboarding) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetCallback,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.fishLog,
            builder: (context, state) => const LogListScreen(),
          ),
          GoRoute(
            path: AppRoutes.rank,
            builder: (context, state) => const RankScreen(),
          ),
          GoRoute(
            path: AppRoutes.weather,
            builder: (context, state) => const WeatherScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Map (ana ekran)
      GoRoute(path: AppRoutes.map, builder: (context, state) => const MapScreen()),
      GoRoute(
        path: AppRoutes.mapAddSpot,
        builder: (context, state) => const AddSpotScreen(),
      ),
      GoRoute(
        path: AppRoutes.mapEditSpot,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! SpotModel) {
            return const Scaffold(body: Center(child: Text('Gecersiz mera')));
          }
          return AddSpotScreen(spotToEdit: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.mapPickLocation,
        builder: (context, state) {
          final extra = state.extra;
          return PickSpotLocationScreen(
            initial: extra is LatLng ? extra : null,
          );
        },
      ),

      // Check-in
      GoRoute(
        path: '${AppRoutes.checkin}/:spotId',
        builder: (_, state) =>
            CheckinScreen(spotId: state.pathParameters['spotId']!),
      ),

      // Fish Log
      GoRoute(
        path: AppRoutes.fishLogAdd,
        builder: (context, state) => const AddLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.fishLogStats,
        builder: (context, state) => const StatsScreen(),
      ),

      // Rank
      GoRoute(
        path: AppRoutes.rankLeaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),

      // Knots
      GoRoute(path: AppRoutes.knots, builder: (context, state) => const KnotsScreen()),
      GoRoute(
        path: AppRoutes.knotsDetail,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is! KnotModel) {
            return const Scaffold(
              body: Center(child: Text('Geçersiz düğüm detayı')),
            );
          }
          return KnotDetailScreen(knot: extra);
        },
      ),

      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationsSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Profile
      GoRoute(
        path: '${AppRoutes.profile}/:userId',
        builder: (context, state) =>
            ProfileScreen(userId: state.pathParameters['userId']),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) =>
        Scaffold(body: Center(child: Text('Sayfa bulunamadı: ${state.uri}'))),
  );
});
