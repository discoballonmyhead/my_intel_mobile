import '../../../../core/constants/db_constants.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/reaction_model.dart';

/// `social.reactions` is only touched through these RPCs, which enforce one
/// reaction per user per post — the same calls the web hook makes.
abstract interface class ReactionRemoteDataSource {
  Future<ReactionSummaryModel> fetchForPost(int postId);
  Future<List<ReactionSummaryModel>> fetchForPosts(List<int> postIds);
  Future<ReactionSummaryModel> toggle(int postId, String type);
}

class ReactionRemoteDataSourceImpl implements ReactionRemoteDataSource {
  ReactionRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<ReactionSummaryModel> fetchForPost(int postId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(ReactionRpc.forPost,
            params: {'p_post_id': postId});
        return ReactionSummaryModel.fromJson(asRow(res) ?? const {},
            postId: postId);
      });

  @override
  Future<List<ReactionSummaryModel>> fetchForPosts(List<int> postIds) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReactionRpc.forPosts,
            params: {'p_post_ids': postIds});
        return asRows(res).map(ReactionSummaryModel.fromRow).toList();
      });

  @override
  Future<ReactionSummaryModel> toggle(int postId, String type) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReactionRpc.toggle,
            params: {'p_post_id': postId, 'p_type': type});
        return ReactionSummaryModel.fromJson(asRow(res) ?? const {},
            postId: postId);
      });
}
