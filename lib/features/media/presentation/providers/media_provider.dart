import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/video.dart';
import '../../domain/usecases/media_usecases.dart';

enum MediaStatus { initial, loading, ready, error }

class MediaProvider extends ChangeNotifier {
  MediaProvider({
    required GetVideos getVideos,
    required ToggleVideoLike toggleVideoLike,
    required GetActiveStreams getActiveStreams,
    required CreateStream createStream,
    required SetStreamStatus setStreamStatus,
  })  : _getVideos = getVideos,
        _toggleVideoLike = toggleVideoLike,
        _getActiveStreams = getActiveStreams,
        _createStream = createStream,
        _setStreamStatus = setStreamStatus;

  final GetVideos _getVideos;
  final ToggleVideoLike _toggleVideoLike;
  final GetActiveStreams _getActiveStreams;
  final CreateStream _createStream;
  final SetStreamStatus _setStreamStatus;

  List<Video> _videos = const [];
  List<LiveStream> _streams = const [];
  MediaStatus _videoStatus = MediaStatus.initial;
  MediaStatus _streamStatus = MediaStatus.initial;
  Failure? _failure;

  List<Video> get videos => _videos;
  List<LiveStream> get streams => _streams;
  MediaStatus get videoStatus => _videoStatus;
  MediaStatus get streamStatus => _streamStatus;
  Failure? get failure => _failure;

  Future<void> loadVideos({String? type = 'reel'}) async {
    _videoStatus = MediaStatus.loading;
    notifyListeners();

    final result = await _getVideos(type);
    result.fold(
      (failure) {
        _failure = failure;
        _videoStatus = MediaStatus.error;
      },
      (videos) {
        _videos = videos;
        _videoStatus = MediaStatus.ready;
      },
    );
    notifyListeners();
  }

  Future<void> toggleLike(Video video) async {
    // Optimistic swap, reconciled below.
    _replaceVideo(video.copyWith(
      likedByMe: !video.likedByMe,
      likes: video.likedByMe
          ? (video.likes - 1).clamp(0, 1 << 30)
          : video.likes + 1,
    ));
    notifyListeners();

    final result = await _toggleVideoLike(video);
    result.fold(
      (failure) {
        _replaceVideo(video);
        _failure = failure;
      },
      _replaceVideo,
    );
    notifyListeners();
  }

  void _replaceVideo(Video video) {
    _videos = _videos.map((v) => v.id == video.id ? video : v).toList();
  }

  Future<void> loadStreams() async {
    _streamStatus = MediaStatus.loading;
    notifyListeners();

    final result = await _getActiveStreams(const NoParams());
    result.fold(
      (failure) {
        _failure = failure;
        _streamStatus = MediaStatus.error;
      },
      (streams) {
        _streams = streams;
        _streamStatus = MediaStatus.ready;
      },
    );
    notifyListeners();
  }

  Future<bool> createStream(String title, {String description = ''}) async {
    final result = await _createStream(
      CreateStreamParams(title: title, description: description),
    );
    return result.fold(
      (failure) {
        _failure = failure;
        notifyListeners();
        return false;
      },
      (stream) {
        _streams = [stream, ..._streams];
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> setStatus(LiveStream stream, LiveStatus status) async {
    final result = await _setStreamStatus(
      SetStreamStatusParams(stream: stream, status: status),
    );
    result.fold(
      (failure) => _failure = failure,
      (updated) {
        _streams = status == LiveStatus.ended
            ? _streams.where((s) => s.id != updated.id).toList()
            : _streams.map((s) => s.id == updated.id ? updated : s).toList();
      },
    );
    notifyListeners();
  }
}
