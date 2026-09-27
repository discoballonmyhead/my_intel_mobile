import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/user_access.dart';
import '../repositories/account_repository.dart';

class GetMyAccess implements UseCase<UserAccess, NoParams> {
  const GetMyAccess(this._repository);
  final AccountRepository _repository;

  @override
  Future<Result<UserAccess>> call(NoParams params) => _repository.getMyAccess();
}

class WatchAccessChanges implements StreamUseCase<void, String> {
  const WatchAccessChanges(this._repository);
  final AccountRepository _repository;

  @override
  Stream<void> call(String userId) => _repository.watchAccessChanges(userId);
}

class DeleteMyAccount implements UseCase<void, String> {
  const DeleteMyAccount(this._repository);
  final AccountRepository _repository;

  @override
  Future<Result<void>> call(String confirmation) async {
    if (confirmation.trim() != AccountRpc.deleteConfirmation) {
      return const Err(ValidationFailure(
          'Type ${AccountRpc.deleteConfirmation} exactly to confirm.'));
    }
    return _repository.deleteMyAccount(confirmation.trim());
  }
}
