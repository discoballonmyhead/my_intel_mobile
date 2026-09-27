/// Every path and route name in one place, so no widget builds a path by hand.
class AppRoutes {
  const AppRoutes._();

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Shell tabs
  static const String feed = '/feed';
  static const String articles = '/articles';
  static const String live = '/live';
  static const String reels = '/reels';
  static const String messages = '/messages';
  static const String profile = '/profile';

  // Messaging (children of /messages, pushed over the shell)
  static const String newMessage = '/messages/new';
  static const String chat = '/messages/:conversationId';
  static const String addMembers = '/messages/:conversationId/add';

  // Pushed routes
  static const String search = '/search';
  static const String settings = '/settings';
  static const String deleteAccount = '/settings/delete-account';
  static const String feedback = '/feedback';
  static const String applyOsint = '/apply';
  static const String channel = '/channel/:username';
  static const String story = '/story/:id';
  static const String myReports = '/reports';
  static const String restricted = '/restricted';

  // Staff console
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminUser = '/admin/users/:userId';
  static const String adminReports = '/admin/reports';
  static const String adminReport = '/admin/reports/:type/:id';
  static const String adminOsint = '/admin/osint';
  static const String adminClaims = '/admin/claims';
  static const String adminAudit = '/admin/audit';

  static String channelFor(String username) => '/channel/$username';
  static String storyFor(int storyId) => '/story/$storyId';
  static String chatFor(String conversationId) => '/messages/$conversationId';
  static String addMembersFor(String conversationId) =>
      '/messages/$conversationId/add';
  static String adminUserFor(String userId) => '/admin/users/$userId';
  static String adminReportFor(String type, String id) =>
      '/admin/reports/$type/$id';

  /// Tabs shown in the bottom bar / nav rail, in order. Must match the
  /// branches in `AppRouter` and `shellDestinations`.
  static const List<String> shellTabs = [feed, articles, reels, messages, profile];

  static const Set<String> publicRoutes = {
    login,
    register,
    verifyEmail,
    forgotPassword,
    resetPassword,
  };

  /// Staff routes that moderators may NOT open (admins only).
  static const Set<String> adminOnlyRoutes = {adminOsint, adminClaims, adminAudit};

  static bool isStaffRoute(String location) =>
      location == admin || location.startsWith('$admin/');
}

/// Named routes, useful for `goNamed` and for analytics labels.
class RouteNames {
  const RouteNames._();

  static const String login = 'login';
  static const String register = 'register';
  static const String verifyEmail = 'verifyEmail';
  static const String forgotPassword = 'forgotPassword';
  static const String resetPassword = 'resetPassword';
  static const String feed = 'feed';
  static const String articles = 'articles';
  static const String live = 'live';
  static const String reels = 'reels';
  static const String messages = 'messages';
  static const String newMessage = 'newMessage';
  static const String chat = 'chat';
  static const String addMembers = 'addMembers';
  static const String profile = 'profile';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String deleteAccount = 'deleteAccount';
  static const String feedback = 'feedback';
  static const String applyOsint = 'applyOsint';
  static const String channel = 'channel';
  static const String story = 'story';
  static const String myReports = 'myReports';
  static const String restricted = 'restricted';
  static const String admin = 'admin';
  static const String adminUsers = 'adminUsers';
  static const String adminUser = 'adminUser';
  static const String adminReports = 'adminReports';
  static const String adminReport = 'adminReport';
  static const String adminOsint = 'adminOsint';
  static const String adminClaims = 'adminClaims';
  static const String adminAudit = 'adminAudit';
}
