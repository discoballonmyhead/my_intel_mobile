import '../../../../core/constants/db_constants.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/credibility_report_model.dart';

abstract interface class CredibilityRemoteDataSource {
  /// Null for non-analysts.
  Future<CredibilityReportModel?> fetch(String userId);
}

class CredibilityRemoteDataSourceImpl implements CredibilityRemoteDataSource {
  CredibilityRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<CredibilityReportModel?> fetch(String userId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(CredibilityRpc.get,
            params: {'p_user_id': userId});
        final row = asRow(res);
        return row == null ? null : CredibilityReportModel.fromJson(row);
      });
}
