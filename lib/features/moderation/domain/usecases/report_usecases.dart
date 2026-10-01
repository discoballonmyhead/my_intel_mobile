import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/report.dart';
import '../repositories/report_repository.dart';

class SubmitReportParams {
  const SubmitReportParams({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
  });
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? details;
}

class SubmitReport implements UseCase<int, SubmitReportParams> {
  const SubmitReport(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<int>> call(SubmitReportParams params) async {
    final details = params.details?.trim();
    if (details != null && details.length > 2000) {
      return const Err(ValidationFailure('Details are limited to 2000 characters.'));
    }
    if (params.reason == ReportReason.other && (details == null || details.isEmpty)) {
      return const Err(ValidationFailure('Tell us a little about the problem.'));
    }
    return _repository.submitReport(
      targetType: params.targetType,
      targetId: params.targetId,
      reason: params.reason,
      details: details == null || details.isEmpty ? null : details,
    );
  }
}

class PageParams {
  const PageParams({this.limit = 50, this.offset = 0});
  final int limit;
  final int offset;
}

class GetMyReports implements UseCase<List<Report>, PageParams> {
  const GetMyReports(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<List<Report>>> call(PageParams params) =>
      _repository.getMyReports(limit: params.limit, offset: params.offset);
}

class ReportQueueParams {
  const ReportQueueParams({
    this.status = ReportStatus.open,
    this.targetType,
    this.limit = 50,
    this.offset = 0,
  });
  final ReportStatus status;
  final ReportTargetType? targetType;
  final int limit;
  final int offset;
}

class GetReportQueue implements UseCase<List<ReportQueueItem>, ReportQueueParams> {
  const GetReportQueue(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<List<ReportQueueItem>>> call(ReportQueueParams params) =>
      _repository.getQueue(
        status: params.status,
        targetType: params.targetType,
        limit: params.limit,
        offset: params.offset,
      );
}

class GetReportsForTarget implements UseCase<List<Report>, ReportTarget> {
  const GetReportsForTarget(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<List<Report>>> call(ReportTarget target) =>
      _repository.getReportsForTarget(target);
}

class ClaimReportTarget implements UseCase<int, ReportTarget> {
  const ClaimReportTarget(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<int>> call(ReportTarget target) => _repository.claimTarget(target);
}

class ResolveReportsParams {
  const ResolveReportsParams({
    required this.target,
    required this.outcome,
    this.action,
    this.note,
  });
  final ReportTarget target;

  /// [ReportStatus.actioned] or [ReportStatus.dismissed].
  final ReportStatus outcome;
  final String? action;
  final String? note;
}

class ResolveReportTarget implements UseCase<int, ResolveReportsParams> {
  const ResolveReportTarget(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<int>> call(ResolveReportsParams params) async {
    if (params.outcome.isPending) {
      return const Err(ValidationFailure('Pick actioned or dismissed.'));
    }
    return _repository.resolveTarget(
      params.target,
      outcome: params.outcome,
      action: params.action,
      note: params.note,
    );
  }
}

class ModContentParams {
  const ModContentParams({required this.id, this.reason});
  final int id;
  final String? reason;
}

class ModRemovePost implements UseCase<void, ModContentParams> {
  const ModRemovePost(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<void>> call(ModContentParams params) async {
    final reason = params.reason?.trim() ?? '';
    if (reason.isEmpty) return const Err(ValidationFailure('A reason is required.'));
    return _repository.removePost(params.id, reason);
  }
}

class ModRestorePost implements UseCase<void, ModContentParams> {
  const ModRestorePost(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<void>> call(ModContentParams params) =>
      _repository.restorePost(params.id, reason: params.reason);
}

class PostVisibilityParams {
  const PostVisibilityParams({
    required this.postId,
    required this.visibility,
    this.reason,
  });
  final int postId;
  final PostVisibility visibility;
  final String? reason;
}

class ModSetPostVisibility implements UseCase<void, PostVisibilityParams> {
  const ModSetPostVisibility(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<void>> call(PostVisibilityParams params) => _repository
      .setPostVisibility(params.postId, params.visibility, reason: params.reason);
}

class ModRemoveMessage implements UseCase<void, ModContentParams> {
  const ModRemoveMessage(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<void>> call(ModContentParams params) async {
    final reason = params.reason?.trim() ?? '';
    if (reason.isEmpty) return const Err(ValidationFailure('A reason is required.'));
    return _repository.removeMessage(params.id, reason);
  }
}

class ModRemoveComment implements UseCase<void, ModContentParams> {
  const ModRemoveComment(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<void>> call(ModContentParams params) async {
    final reason = params.reason?.trim() ?? '';
    if (reason.isEmpty) return const Err(ValidationFailure('A reason is required.'));
    return _repository.removeComment(params.id, reason);
  }
}

class WarnUserParams {
  const WarnUserParams({required this.userId, required this.reason, this.reportId});
  final String userId;
  final String reason;
  final int? reportId;
}

class WarnUser implements UseCase<int, WarnUserParams> {
  const WarnUser(this._repository);
  final ReportRepository _repository;

  @override
  Future<Result<int>> call(WarnUserParams params) async {
    if (params.reason.trim().isEmpty) {
      return const Err(ValidationFailure('A reason is required.'));
    }
    return _repository.warnUser(params.userId, params.reason.trim(),
        reportId: params.reportId);
  }
}

class WatchReports implements StreamUseCase<void, NoParams> {
  const WatchReports(this._repository);
  final ReportRepository _repository;

  @override
  Stream<void> call(NoParams params) => _repository.watchReports();
}
