import 'package:equatable/equatable.dart';

/// An analyst's credibility and how it was reached, from `credibility_get`.
/// Same model and field names as the web `useCredibility` breakdown:
/// each news post (last 180 days) starts at 50 and gains / loses points for
/// citations, timing, peer corroboration, reactions and claim outcomes; the
/// average (or 80 with no posts) gets note-accuracy and consistency boosts.
class CredibilityReport extends Equatable {
  const CredibilityReport({
    required this.score,
    this.avgPostScore = 0,
    this.totalPosts = 0,
    this.totalCited = 0,
    this.totalPeerCorr = 0,
    this.totalReactions = 0,
    this.positiveReactions = 0,
    this.negativeReactions = 0,
    this.falseClaims = 0,
    this.verifiedClaims = 0,
    this.noteBoost = 0,
    this.consistencyBoost = 0,
    this.activeDays = 0,
    this.accurateNotes = 0,
    this.totalRatedNotes = 0,
  });

  /// 0–100.
  final int score;
  final int avgPostScore;
  final int totalPosts;
  final int totalCited;
  final int totalPeerCorr;
  final int totalReactions;
  final int positiveReactions;
  final int negativeReactions;
  final int falseClaims;
  final int verifiedClaims;

  /// 0–5: share of the analyst's rated community notes judged accurate.
  final int noteBoost;

  /// 0–5: active posting days in the last 30.
  final int consistencyBoost;
  final int activeDays;
  final int accurateNotes;
  final int totalRatedNotes;

  static const int newAnalystBaseline = 80;

  /// No news posts in the window yet, so the score starts from 80.
  bool get isBaseline => totalPosts == 0;

  int get baseScore => isBaseline ? newAnalystBaseline : avgPostScore;

  @override
  List<Object?> get props => [
        score,
        avgPostScore,
        totalPosts,
        totalCited,
        totalPeerCorr,
        totalReactions,
        positiveReactions,
        negativeReactions,
        falseClaims,
        verifiedClaims,
        noteBoost,
        consistencyBoost,
        activeDays,
        accurateNotes,
        totalRatedNotes,
      ];
}
