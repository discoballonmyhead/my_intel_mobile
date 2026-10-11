import 'package:equatable/equatable.dart';

/// The four reactions the web app offers (REACTION_TYPES in useReactions).
enum ReactionType {
  verified('verified', 'Verified'),
  confirmed('confirmed', 'Confirmed'),
  disputed('disputed', 'Disputed'),
  breaking('breaking', 'Breaking');

  const ReactionType(this.value, this.label);

  final String value;
  final String label;

  static ReactionType? fromValue(String? value) {
    for (final type in ReactionType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// Counts toward an analyst's credibility (+3 each).
  bool get isPositive => this == verified || this == confirmed;
}

/// Reaction counts on one post plus the viewer's own reaction.
class ReactionSummary extends Equatable {
  const ReactionSummary({
    required this.postId,
    this.counts = const {},
    this.userReaction,
  });

  final int postId;
  final Map<ReactionType, int> counts;

  /// Null when the viewer hasn't reacted.
  final ReactionType? userReaction;

  int countOf(ReactionType type) => counts[type] ?? 0;

  int get total => ReactionType.values.fold(0, (sum, t) => sum + countOf(t));

  /// The same rules as `reaction_toggle`, applied locally so the tap is
  /// instant: same type removes it, another type switches, none adds.
  ReactionSummary toggled(ReactionType type) {
    final next = Map<ReactionType, int>.of(counts);
    void bump(ReactionType t, int delta) {
      final value = countOf(t) + delta;
      next[t] = value < 0 ? 0 : value;
    }

    final current = userReaction;
    if (current == type) {
      bump(type, -1);
      return ReactionSummary(postId: postId, counts: next);
    }
    if (current != null) bump(current, -1);
    bump(type, 1);
    return ReactionSummary(postId: postId, counts: next, userReaction: type);
  }

  @override
  List<Object?> get props => [postId, counts, userReaction];
}
