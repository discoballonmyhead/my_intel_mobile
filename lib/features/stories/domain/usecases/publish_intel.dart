import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/story.dart';
import '../repositories/story_repository.dart';

class PublishIntelParams {
  const PublishIntelParams({
    required this.body,
    required this.tag,
    required this.region,
    this.regionLat,
    this.regionLng,
    this.attachToStoryId,
    this.headline,
    this.summary,
  });

  final String body;
  final String tag;
  final String region;
  final double? regionLat;
  final double? regionLng;

  /// When set, the post is attached to this existing story instead of being
  /// auto-clustered.
  final int? attachToStoryId;
  final String? headline;
  final String? summary;
}

class PublishIntel implements UseCase<Story?, PublishIntelParams> {
  const PublishIntel(this._repository);

  static const int minBodyLength = 20;

  final StoryRepository _repository;

  @override
  Future<Result<Story?>> call(PublishIntelParams params) async {
    final body = params.body.trim();
    if (body.length < minBodyLength) {
      return const Err(ValidationFailure(
        'An intelligence report needs at least 20 characters.',
      ));
    }
    if (params.tag.isEmpty) {
      return const Err(ValidationFailure('Pick a tag for this report.'));
    }

    return _repository.publishIntel(
      body: body,
      tag: params.tag,
      region: params.region.isEmpty ? 'Global' : params.region,
      regionLat: params.regionLat,
      regionLng: params.regionLng,
      attachToStoryId: params.attachToStoryId,
      headline: params.headline,
      summary: params.summary,
    );
  }
}
