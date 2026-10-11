import '../../../../core/network/rpc_runner.dart';
import '../../domain/entities/credibility_report.dart';

class CredibilityReportModel extends CredibilityReport {
  const CredibilityReportModel({
    required super.score,
    super.avgPostScore,
    super.totalPosts,
    super.totalCited,
    super.totalPeerCorr,
    super.totalReactions,
    super.positiveReactions,
    super.negativeReactions,
    super.falseClaims,
    super.verifiedClaims,
    super.noteBoost,
    super.consistencyBoost,
    super.activeDays,
    super.accurateNotes,
    super.totalRatedNotes,
  });

  /// `{score, breakdown: {...}}` — breakdown keys are camelCase, matching the
  /// object the web hook has always exposed.
  factory CredibilityReportModel.fromJson(Map<String, dynamic> json) {
    final raw = json['breakdown'];
    final b = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    int n(String key) => asInt(b[key]) ?? 0;
    return CredibilityReportModel(
      score: asInt(json['score']) ?? 0,
      avgPostScore: n('avgPostScore'),
      totalPosts: n('totalPosts'),
      totalCited: n('totalCited'),
      totalPeerCorr: n('totalPeerCorr'),
      totalReactions: n('totalReactions'),
      positiveReactions: n('positiveReactions'),
      negativeReactions: n('negativeReactions'),
      falseClaims: n('falseClaims'),
      verifiedClaims: n('verifiedClaims'),
      noteBoost: n('noteBoost'),
      consistencyBoost: n('consistencyBoost'),
      activeDays: n('activeDays'),
      accurateNotes: n('accurateNotes'),
      totalRatedNotes: n('totalRatedNotes'),
    );
  }
}
