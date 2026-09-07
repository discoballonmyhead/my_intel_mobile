import '../../../../core/usecases/usecase.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class WatchAuthState implements StreamUseCase<AuthUser?, NoParams> {
  const WatchAuthState(this._repository);

  final AuthRepository _repository;

  @override
  Stream<AuthUser?> call(NoParams params) => _repository.authStateChanges;
}
