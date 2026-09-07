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
  static const String profile = '/profile';

  // Pushed routes
  static const String search = '/search';
  static const String settings = '/settings';
  static const String feedback = '/feedback';
  static const String admin = '/admin';
  static const String applyOsint = '/apply';
  static const String channel = '/channel/:username';
  static const String story = '/story/:id';

  static String channelFor(String username) => '/channel/$username';
  static String storyFor(int storyId) => '/story/$storyId';

  /// Tabs shown in the bottom bar / nav rail, in order.
  static const List<String> shellTabs = [feed, articles, live, reels, profile];

  static const Set<String> publicRoutes = {
    login,
    register,
    verifyEmail,
    forgotPassword,
    resetPassword,
  };
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
  static const String profile = 'profile';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String feedback = 'feedback';
  static const String admin = 'admin';
  static const String applyOsint = 'applyOsint';
  static const String channel = 'channel';
  static const String story = 'story';
}
