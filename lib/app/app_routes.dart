/// Route path sabitleri — go_router'da ve context.go/push çağrılarında kullan.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const resetCallback = '/reset-callback';
  /// E-posta / Site URL ile aynı ekran — Supabase redirect'te `/reset-callback` veya bunu kullan.
  static const resetPassword = '/reset-password';
  static const onboarding = '/onboarding';

  // Shell (BottomNav)
  static const home = '/home';
  static const fishLog = '/fish-log';
  static const social = '/social';
  static const socialFriends = '/social/friends';
  static const socialRequests = '/social/requests';
  static const rank = '/rank';
  static const weather = '/weather';
  static const profile = '/profile';

  // Map
  static const map = '/map';
  static const mapAddSpot = '/map/add-spot';
  static const mapEditSpot = '/map/edit-spot';
  static const mapPickLocation = '/map/pick-location';

  // Check-in
  static const checkin = '/checkin';

  // Fish Log
  static const fishLogAdd = '/fish-log/add';
  static const fishLogStats = '/fish-log/stats';

  // Knots
  static const knots = '/knots';
  static const knotsDetail = '/knots/detail';

  // Notifications
  static const notifications = '/notifications';
  static const notificationsSettings = '/notifications/settings';

  // Profile
  static const settings = '/settings';
}
