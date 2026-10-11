import '../../../../core/network/rpc_runner.dart';
import '../../domain/entities/reaction.dart';

class ReactionSummaryModel extends ReactionSummary {
  const ReactionSummaryModel({
    required super.postId,
    super.counts,
    super.userReaction,
  });

  /// jsonb from `reaction_toggle` / `reaction_get_for_post`:
  /// `{post_id, counts: {verified: 1, …}, total, user_reaction}`.
  factory ReactionSummaryModel.fromJson(Map<String, dynamic> json,
      {int? postId}) {
    final raw = json['counts'];
    final counts = <ReactionType, int>{
      for (final type in ReactionType.values)
        type: raw is Map ? asInt(raw[type.value]) ?? 0 : 0,
    };
    return ReactionSummaryModel(
      postId: asInt(json['post_id']) ?? postId ?? 0,
      counts: counts,
      userReaction: ReactionType.fromValue(json['user_reaction'] as String?),
    );
  }

  /// A row of `reaction_get_for_posts`: one column per type.
  factory ReactionSummaryModel.fromRow(Map<String, dynamic> row) {
    return ReactionSummaryModel(
      postId: asInt(row['post_id']) ?? 0,
      counts: {
        for (final type in ReactionType.values)
          type: asInt(row[type.value]) ?? 0,
      },
      userReaction: ReactionType.fromValue(row['user_reaction'] as String?),
    );
  }
}
