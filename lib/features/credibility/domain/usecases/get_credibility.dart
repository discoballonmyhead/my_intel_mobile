import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/credibility_report.dart';
import '../repositories/credibility_repository.dart';

class GetCredibility implements UseCase<CredibilityReport?, String> {
  const GetCredibility(this._repository);
  final CredibilityRepository _repository;

  @override
  Future<Result<CredibilityReport?>> call(String userId) =>
      _repository.getCredibility(userId);
}
