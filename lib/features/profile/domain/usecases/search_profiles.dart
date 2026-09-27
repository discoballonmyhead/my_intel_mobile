import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class SearchProfilesParams {
  const SearchProfilesParams({required this.query, this.limit = 20});
  final String query;
  final int limit;
}

/// People search used by the new-message picker.
class SearchProfiles implements UseCase<List<Profile>, SearchProfilesParams> {
  const SearchProfiles(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Result<List<Profile>>> call(SearchProfilesParams params) async {
    final query = params.query.trim().replaceFirst(RegExp(r'^@'), '');
    if (query.isEmpty) return const Ok(<Profile>[]);
    return _repository.searchProfiles(query, limit: params.limit);
  }
}
