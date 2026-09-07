import 'package:intl/intl.dart';

extension RelativeTime on DateTime {
  /// Compact "time ago" label used across feed cards and story headers.
  String get timeAgo {
    final diff = DateTime.now().toUtc().difference(toUtc());
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 365) return DateFormat('d MMM').format(toLocal());
    return DateFormat('d MMM yyyy').format(toLocal());
  }

  String get absolute => DateFormat('d MMM yyyy, HH:mm').format(toLocal());
}

/// Safe parsing for timestamps coming back from PostgREST as strings.
DateTime? parseTimestamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toUtc();
}
