import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_data_source.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._remote);
  final AccountRemoteDataSource _remote;

  @override
  Future<Result<UserAccess>> getMyAccess() => guard(_remote.fetchMyAccess);

  @override
  Stream<void> watchAccessChanges(String userId) =>
      _remote.watchAccessChanges(userId);

  @override
  Future<Result<void>> deleteMyAccount(String confirmation) =>
      guard(() => _remote.deleteSelf(confirmation));
}
