import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/credibility_report.dart';
import '../../domain/repositories/credibility_repository.dart';
import '../datasources/credibility_remote_data_source.dart';

class CredibilityRepositoryImpl implements CredibilityRepository {
  CredibilityRepositoryImpl(this._remote);
  final CredibilityRemoteDataSource _remote;

  @override
  Future<Result<CredibilityReport?>> getCredibility(String userId) =>
      guard(() => _remote.fetch(userId));
}
