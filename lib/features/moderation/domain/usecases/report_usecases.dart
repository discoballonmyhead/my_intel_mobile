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
