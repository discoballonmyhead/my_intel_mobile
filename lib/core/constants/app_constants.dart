/// Canonical taxonomy shared by composer, articles, search and filters.
/// Mirrors `src/constants.js` from the web client.
class AppConstants {
  const AppConstants._();

  static const List<String> storyTags = [
    'CONFLICT', 'CYBER', 'GEOPOLITICS', 'MILITARY', 'HUMANITARIAN',
    'NUCLEAR', 'MARITIME', 'INTELLIGENCE', 'BREAKING', 'SECURITY',
    'ECONOMIC', 'ENERGY', 'OTHER',
  ];

  static const List<String> composerTags = [
    'MILITARY', 'CYBER', 'MARITIME', 'GEOPOLITICAL', 'HUMANITARIAN',
    'ECONOMIC', 'ENERGY', 'OTHER',
  ];

  static const List<String> mapFilters = [
    'ALL', 'CONFLICT', 'MARITIME', 'CYBER',
    'MILITARY', 'GEOPOLITICS', 'NUCLEAR', 'SECURITY',
  ];

  static const int feedPageSize = 50;
  static const int searchPageSize = 20;

  /// Weight of `challenges` notes needed before a claim is raised.
  /// Matches `moderation.check_claim_threshold()`.
  static const int claimThreshold = 5;
}

/// Time windows used by trending ranking and search date filters.
enum TimeWindow {
  hour('1h', 'Past Hour', Duration(hours: 1)),
  day('24h', 'Past 24h', Duration(hours: 24)),
  week('7d', 'Past Week', Duration(days: 7)),
  all('all', 'All Time', null);

  const TimeWindow(this.id, this.label, this.duration);

  final String id;
  final String label;
  final Duration? duration;

  DateTime? get cutoff =>
      duration == null ? null : DateTime.now().toUtc().subtract(duration!);
}
