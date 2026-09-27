import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._remote, this._profiles);

  final ReportRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

  @override
  Future<Result<int>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) =>
      guard(() => _remote.report(
            targetType: targetType.value,
            targetId: targetId,
            reason: reason.value,
            details: details,
          ));

  @override
  Future<Result<List<Report>>> getMyReports({int limit = 50, int offset = 0}) =>
      guard(() async {
        final rows = await _remote.myReports(limit: limit, offset: offset);
        return rows.map(ReportModel.fromJson).toList();
      });

  @override
  Future<Result<List<ReportQueueItem>>> getQueue({
    ReportStatus status = ReportStatus.open,
    ReportTargetType? targetType,
    int limit = 50,
    int offset = 0,
  }) =>
      guard(() async {
        final rows = await _remote.queue(
          // 'open' in the RPC means open + in_review.
          status: status == ReportStatus.inReview ? 'open' : status.value,
          targetType: targetType?.value,
          limit: limit,
          offset: offset,
        );
        final owners = await runRpc(() => _profiles
            .profilesByIds(rows.map((r) => r['target_owner_id'] as String?)));
        return rows
            .map((r) => ReportQueueItemModel.fromJson(r,
                owner: owners[r['target_owner_id'] as String?]))
            .toList();
      });

  @override
  Future<Result<List<Report>>> getReportsForTarget(ReportTarget target) =>
      guard(() async {
        final rows = await _remote.forTarget(target.type.value, target.id);
        final reporters = await runRpc(() => _profiles
            .profilesByIds(rows.map((r) => r['reporter_id'] as String?)));
        return rows
            .map((r) => ReportModel.fromJson(r,
                reporter: reporters[r['reporter_id'] as String?]))
            .toList();
      });

  @override
  Future<Result<int>> claimTarget(ReportTarget target) =>
      guard(() => _remote.claimTarget(target.type.value, target.id));

  @override
  Future<Result<int>> resolveTarget(
    ReportTarget target, {
    required ReportStatus outcome,
    String? action,
    String? note,
  }) =>
      guard(() => _remote.resolveTarget(
            target.type.value,
            target.id,
            outcome: outcome.value,
            action: action,
            note: note,
          ));

  @override
  Future<Result<void>> removePost(int postId, String reason) =>
      guard(() => _remote.removePost(postId, reason));

  @override
  Future<Result<void>> restorePost(int postId, {String? reason}) =>
      guard(() => _remote.restorePost(postId, reason));

  @override
  Future<Result<void>> setPostVisibility(int postId, PostVisibility visibility,
          {String? reason}) =>
      guard(() => _remote.setPostVisibility(postId, visibility.value, reason));

  @override
  Future<Result<void>> removeMessage(int messageId, String reason) =>
      guard(() => _remote.removeMessage(messageId, reason));

  @override
  Future<Result<int>> warnUser(String userId, String reason, {int? reportId}) =>
      guard(() => _remote.warnUser(userId, reason, reportId));

  @override
  Stream<void> watchReports() => _remote.watchReports();
}
