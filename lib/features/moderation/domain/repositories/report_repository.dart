import '../../../../core/utils/result.dart';
import '../entities/report.dart';

abstract interface class ReportRepository {
  // Any signed-in user
  Future<Result<int>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  });
  Future<Result<List<Report>>> getMyReports({int limit = 50, int offset = 0});

  // Staff
  Future<Result<List<ReportQueueItem>>> getQueue({
    ReportStatus status = ReportStatus.open,
    ReportTargetType? targetType,
    int limit = 50,
    int offset = 0,
  });
  Future<Result<List<Report>>> getReportsForTarget(ReportTarget target);
  Future<Result<int>> claimTarget(ReportTarget target);
  Future<Result<int>> resolveTarget(
    ReportTarget target, {
    required ReportStatus outcome,
    String? action,
    String? note,
  });
  Future<Result<void>> removePost(int postId, String reason);
  Future<Result<void>> restorePost(int postId, {String? reason});
  Future<Result<void>> setPostVisibility(
      int postId, PostVisibility visibility, {String? reason});
  Future<Result<void>> removeMessage(int messageId, String reason);
  Future<Result<int>> warnUser(String userId, String reason, {int? reportId});

  /// Ticks when any report is filed or changes state (staff only via RLS).
  Stream<void> watchReports();
}
