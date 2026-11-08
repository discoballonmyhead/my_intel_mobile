import '../../../core/constants/db_constants.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/rpc_runner.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/utils/result.dart';
import '../domain/lean.dart';

/// The signed-in user's compass. Every call works on the caller's own data;
/// no call takes a user id, so nobody can read someone else's position.
class LeanRepository {
  LeanRepository(this._service);

  final SupabaseService _service;

  Future<Result<LeanStatus>> me() => _status(LeanRpc.me);

  Future<Result<LeanStatus>> reset() => _status(LeanRpc.reset);

  Future<Result<LeanStatus>> setSettings({
    required bool enabled,
    LeanMode mode = LeanMode.off,
    LeanPoint? spot,
  }) =>
      _status(LeanRpc.setSettings, {
        'p_enabled': enabled,
        'p_mode': mode.name,
        'p_spot_x': spot?.x,
        'p_spot_y': spot?.y,
      });

  Future<Result<LeanStatus>> _status(String rpc, [Map<String, dynamic>? params]) =>
      guard(() => runRpc(() async {
            final row = asRow(await _service.rpc<dynamic>(rpc, params: params));
            return row == null ? LeanStatus.disabled : LeanStatus.fromJson(row);
          }));
}
