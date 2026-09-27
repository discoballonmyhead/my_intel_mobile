import '../../../../core/utils/result.dart';
import '../entities/user_access.dart';

abstract interface class AccountRepository {
  /// Roles, ban state and active sanctions for the signed-in user.
  Future<Result<UserAccess>> getMyAccess();

  /// Emits whenever this user's roles or sanctions change (realtime on
  /// `admin.user_roles` and `admin.sanctions`). Listeners refetch on each tick.
  Stream<void> watchAccessChanges(String userId);

  /// Permanently deletes the signed-in account. [confirmation] must be the
  /// exact phrase the RPC expects.
  Future<Result<void>> deleteMyAccount(String confirmation);
}
