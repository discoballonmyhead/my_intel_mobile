import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/video.dart';
import '../repositories/media_repository.dart';

class GetVideos implements UseCase<List<Video>, String?> {
  const GetVideos(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<List<Video>>> call(String? type) =>
      _repository.getVideos(type: type);
}

class ToggleVideoLike implements UseCase<Video, Video> {
  const ToggleVideoLike(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<Video>> call(Video video) => _repository.toggleVideoLike(video);
}

class GetActiveStreams implements UseCase<List<LiveStream>, NoParams> {
  const GetActiveStreams(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<List<LiveStream>>> call(NoParams params) =>
      _repository.getActiveStreams();
}

class CreateStreamParams {
  const CreateStreamParams({required this.title, this.description = ''});
  final String title;
  final String description;
}

class CreateStream implements UseCase<LiveStream, CreateStreamParams> {
  const CreateStream(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<LiveStream>> call(CreateStreamParams params) async {
    if (params.title.trim().isEmpty) {
      return const Err(ValidationFailure('Give the stream a title.'));
    }
    return _repository.createStream(
      title: params.title.trim(),
      description: params.description.trim(),
    );
  }
}

class SetStreamStatusParams {
  const SetStreamStatusParams({required this.stream, required this.status});
  final LiveStream stream;
  final LiveStatus status;
}

class SetStreamStatus implements UseCase<LiveStream, SetStreamStatusParams> {
  const SetStreamStatus(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<LiveStream>> call(SetStreamStatusParams params) =>
      _repository.setStreamStatus(params.stream, params.status);
}
