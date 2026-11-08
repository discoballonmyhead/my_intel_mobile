import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../e2ee/domain/message_crypto.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._remote, {MessageEvidenceSource? evidence})
      : _evidence = evidence;

  final ReportRemoteDataSource _remote;
  final MessageEvidenceSource? _evidence;

  @override
  Future<Result<int>> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) =>
      guard(() async {
        // Encrypted messages: moderators only see what the reporter's phone
        // proves was sent (message franking, migration 18).
        if (targetType == ReportTargetType.message) {
          final id = int.tryParse(targetId);
          final proof = id == null ? null : await _evidence?.evidenceFor(id);
          if (id != null && proof != null) {
            return _remote.reportEncryptedMessage(
              messageId: id,
              reason: reason.value,
              plaintext: proof.plaintext,
              frankingKey: proof.frankingKey,
              details: details,
            );
          }
        }
        return _remote.report(
          targetType: targetType.value,
          targetId: targetId,
          reason: reason.value,
          details: details,
        );
      });

  @override
  Future<Result<List<Report>>> getMyReports({int limit = 50, int offset = 0}) =>
      guard(() async {
        final rows = await _remote.myReports(limit: limit, offset: offset);
        return rows.map(ReportModel.fromJson).toList();
      });
}
