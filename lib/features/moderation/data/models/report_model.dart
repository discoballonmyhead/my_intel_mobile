import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/report.dart';

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

class ReportModel extends Report {
  const ReportModel({
    required super.id,
    required super.targetType,
    required super.targetId,
    required super.reason,
    required super.status,
    required super.createdAt,
    super.reporterId,
    super.reporter,
    super.targetOwnerId,
    super.details,
    super.snapshot,
    super.assignedTo,
    super.resolvedBy,
    super.resolvedAt,
    super.resolutionAction,
    super.resolutionNote,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json, {Profile? reporter}) {
    return ReportModel(
      id: asInt(json['id']) ?? 0,
      targetType: ReportTargetType.fromValue(json['target_type'] as String?),
      targetId: '${json['target_id']}',
      reason: ReportReason.fromValue(json['reason'] as String?),
      status: ReportStatus.fromValue(json['status'] as String?),
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      reporterId: json['reporter_id'] as String?,
      reporter: reporter,
      targetOwnerId: json['target_owner_id'] as String?,
      details: json['details'] as String?,
      snapshot: ReportSnapshot(_asMap(json['content_snapshot'])),
      assignedTo: json['assigned_to'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: parseTimestamp(json['resolved_at']),
      resolutionAction: json['resolution_action'] as String?,
      resolutionNote: json['resolution_note'] as String?,
    );
  }
}

class ReportQueueItemModel extends ReportQueueItem {
  const ReportQueueItemModel({
    required super.targetType,
    required super.targetId,
    required super.reportCount,
    required super.reporterCount,
    required super.reasons,
    required super.firstReportedAt,
    required super.lastReportedAt,
    super.targetOwnerId,
    super.owner,
    super.snapshot,
    super.assignedTo,
    super.ownerPriorSanctions,
  });

  factory ReportQueueItemModel.fromJson(Map<String, dynamic> json,
      {Profile? owner}) {
    final now = DateTime.now().toUtc();
    return ReportQueueItemModel(
      targetType: ReportTargetType.fromValue(json['target_type'] as String?),
      targetId: '${json['target_id']}',
      reportCount: asInt(json['report_count']) ?? 0,
      reporterCount: asInt(json['reporter_count']) ?? 0,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((r) => ReportReason.fromValue(r as String?))
          .toList(),
      firstReportedAt: parseTimestamp(json['first_reported_at']) ?? now,
      lastReportedAt: parseTimestamp(json['last_reported_at']) ?? now,
      targetOwnerId: json['target_owner_id'] as String?,
      owner: owner,
      snapshot: ReportSnapshot(_asMap(json['latest_snapshot'])),
      assignedTo: json['assigned_to'] as String?,
      ownerPriorSanctions: asInt(json['owner_prior_sanctions']) ?? 0,
    );
  }
}
