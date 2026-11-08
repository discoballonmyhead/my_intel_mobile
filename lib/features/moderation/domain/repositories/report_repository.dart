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
}
