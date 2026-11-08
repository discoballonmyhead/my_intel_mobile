import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/result.dart';

/// Asking for the Reporter or OSINT badge (migration 15). Staff review the
/// request in the admin app under Badge requests.
class BadgeRequests {
  BadgeRequests(this._service);
  final SupabaseService _service;

  /// Sends (or updates the pending) request. [badge] is `reporter` or `osint`.
  Future<Result<void>> request(String badge, {String? note, List<String> links = const []}) =>
      guard(() => runRpc(() => _service.rpc<dynamic>('badge_request_create', params: {
            'p_badge': badge,
            'p_note': note,
            'p_links': links,
          })));

  /// This account's requests, newest first: `{badge, status, review_note, …}`.
  Future<Result<List<Map<String, dynamic>>>> mine() =>
      guard(() => runRpc(() async => asRows(await _service.rpc<dynamic>('badge_get_my_requests'))));
}
