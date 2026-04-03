/// Route path sabitleri — go_router'da ve context.go/push çağrılarında kullan.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const resetCallback = '/reset-callback';
  static const resetPassword = '/reset-password';
  static const onboarding = '/onboarding';

  // Shell (BottomNav)
  static const home = '/home';
  static const fishLog = '/fish-log';
  static const rank = '/rank';
  static const weather = '/weather';
  static const profile = '/profile';

  // Map
  static const map = '/map';
  static const mapAddSpot = '/map/add-spot';
  static const mapEditSpot = '/map/edit-spot';
  static const mapPickLocation = '/map/pick-location';

  // Check-in (spotId parametresi ile birleştirilmeli: '/checkin/$spotId')
  static const checkin = '/checkin';

  // Fish Log (legacy paths korundu)
  static const logs = '/logs';
  static const logsAdd = '/logs/add';
  static const logsStats = '/logs/stats';
  static const fishLogAdd = '/fish-log/add';
  static const fishLogStats = '/fish-log/stats';
  static const log = '/log';
  static const logAdd = '/log/add';

  // Rank
  static const rankLeaderboard = '/rank/leaderboard';
  static const leaderboard = '/leaderboard';

  // Knots
  static const knots = '/knots';
  static const knotsDetail = '/knots/detail';

  // Notifications
  static const notifications = '/notifications';
  static const notificationsSettings = '/notifications/settings';

  // Profile
  static const settings = '/settings';
  static const profileSettings = '/profile/settings';
}
