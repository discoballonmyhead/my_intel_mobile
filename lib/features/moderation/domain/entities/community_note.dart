import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

/// Which side of a post a note takes. Stored as text in
/// `moderation.community_notes.stance`.
enum NoteStance {
  supports('supports'),
  challenges('challenges');

  const NoteStance(this.value);
  final String value;

  static NoteStance fromValue(String? value) =>
      value == 'challenges' ? NoteStance.challenges : NoteStance.supports;
}

/// A row of `moderation.community_notes`.
///
/// `weight` is assigned by the `trg_note_weight` trigger from the author's
/// role — admin 10, osint 3, everyone else 1 — so it is read-only here.
class CommunityNote extends Equatable {
  const CommunityNote({
    required this.id,
    required this.postId,
    required this.body,
    required this.stance,
    this.authorId,
    this.author,
    this.accuracyRating,
    this.weight = 1,
    this.createdAt,
  });

  final int id;
  final int postId;
  final String body;
  final NoteStance stance;
  final String? authorId;
  final Profile? author;

  /// Set by an admin: 'accurate' | 'inaccurate' | null.
  final String? accuracyRating;
  final int weight;
  final DateTime? createdAt;

  bool get challenges => stance == NoteStance.challenges;

  @override
  List<Object?> get props => [id, postId, stance, weight, accuracyRating];
}

/// A row of `moderation.claims` — opened automatically once challenging notes
/// reach the weight threshold.
class Claim extends Equatable {
  const Claim({
    required this.id,
    required this.postId,
    this.status = 'open',
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    this.createdAt,
  });

  final int id;
  final int postId;

  /// 'open' | 'verified' | 'false' | 'reversed'
  final String status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => [id, postId, status];
}

/// Everything the UI needs to render the moderation state of one post.
class PostModeration extends Equatable {
  const PostModeration({
    this.claim,
    this.notes = const [],
    this.myNote,
  });

  final Claim? claim;
  final List<CommunityNote> notes;

  /// The current user's note, if they have already written one — the database
  /// allows only one per person per post in practice.
  final CommunityNote? myNote;

  int get challengeWeight => notes
      .where((n) => n.challenges)
      .fold(0, (sum, n) => sum + n.weight);

  int get supportWeight => notes
      .where((n) => !n.challenges)
      .fold(0, (sum, n) => sum + n.weight);

  /// Mirrors `moderation.check_claim_threshold()`: a claim is surfaced once
  /// challenging weight reaches 5, or as soon as one actually exists.
  bool get isDisputed => challengeWeight >= 5 || claim != null;

  @override
  List<Object?> get props => [claim, notes, myNote];
}
