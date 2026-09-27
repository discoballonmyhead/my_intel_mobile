import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post_edit.dart';
import '../../domain/usecases/manage_post.dart';

class PostEditHistoryState extends Equatable {
  const PostEditHistoryState({
    this.edits = const [],
    this.isLoading = true,
    this.failure,
  });

  final List<PostEdit> edits;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => [edits, isLoading, failure];
}

class PostEditHistoryCubit extends Cubit<PostEditHistoryState> {
  PostEditHistoryCubit({
    required int postId,
    required GetPostEditHistory getHistory,
  })  : _postId = postId,
        _getHistory = getHistory,
        super(const PostEditHistoryState());

  final int _postId;
  final GetPostEditHistory _getHistory;

  Future<void> load() async {
    final result = await _getHistory(_postId);
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(PostEditHistoryState(isLoading: false, failure: failure)),
      (edits) => emit(PostEditHistoryState(edits: edits, isLoading: false)),
    );
  }
}
