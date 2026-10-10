import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/domain/usecases/get_post.dart';
import '../../../feed/domain/usecases/toggle_interaction.dart';
import '../../domain/entities/comment.dart';
import '../../domain/usecases/comment_usecases.dart';

enum PostDetailStatus { loading, ready, error }

class PostDetailState extends Equatable {
  const PostDetailState({
    required this.postId,
    this.myUserId,
    this.status = PostDetailStatus.loading,
    this.post,
    this.comments = const [],
    this.replies = const {},
    this.expanded = const {},
    this.loadingReplies = const {},
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.replyTo,
    this.editing,
    this.failure,
    this.actionFailure,
  });

  final int postId;
  final String? myUserId;
  final PostDetailStatus status;
  final Post? post;

  /// Top-level comments, newest first.
  final List<Comment> comments;

  /// Loaded replies per thread root id, oldest first.
  final Map<int, List<Comment>> replies;

  /// Threads currently showing their replies.
  final Set<int> expanded;
  final Set<int> loadingReplies;

  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final Comment? replyTo;
  final Comment? editing;
  final Failure? failure;
  final Failure? actionFailure;

  int get commentCount => post?.replyCount ?? 0;

  List<Comment> repliesOf(int rootId) => replies[rootId] ?? const [];

  bool hasMoreReplies(Comment root) =>
      repliesOf(root.id).length < root.replyCount;

  PostDetailState copyWith({
    PostDetailStatus? status,
    Post? post,
    List<Comment>? comments,
    Map<int, List<Comment>>? replies,
    Set<int>? expanded,
    Set<int>? loadingReplies,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    Comment? replyTo,
    Comment? editing,
    Failure? failure,
    Failure? actionFailure,
    bool clearReplyTo = false,
    bool clearEditing = false,
    bool clearActionFailure = false,
  }) {
    return PostDetailState(
      postId: postId,
      myUserId: myUserId,
      status: status ?? this.status,
      post: post ?? this.post,
      comments: comments ?? this.comments,
      replies: replies ?? this.replies,
      expanded: expanded ?? this.expanded,
      loadingReplies: loadingReplies ?? this.loadingReplies,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      replyTo: clearReplyTo ? null : replyTo ?? this.replyTo,
      editing: clearEditing ? null : editing ?? this.editing,
      failure: failure ?? this.failure,
      actionFailure:
          clearActionFailure ? null : actionFailure ?? this.actionFailure,
    );
  }

  @override
  List<Object?> get props => [
        postId,
        status,
        post,
        comments,
        replies,
        expanded,
        loadingReplies,
        hasMore,
        isLoadingMore,
        isSending,
        replyTo,
        editing,
        failure,
        actionFailure,
      ];
}

/// A post with its comment threads. Route-scoped (get_it factory param =
/// post id); closes its realtime channel when the page goes away.
class PostDetailCubit extends Cubit<PostDetailState> {
  PostDetailCubit({
    required int postId,
    required String? myUserId,
    required GetPost getPost,
    required ToggleLike toggleLike,
    required ToggleSave toggleSave,
    required ToggleRepost toggleRepost,
    required GetComments getComments,
    required GetReplies getReplies,
    required CreateComment createComment,
    required EditComment editComment,
    required DeleteComment deleteComment,
    required ToggleCommentLike toggleCommentLike,
    required WatchPostComments watchComments,
  })  : _getPost = getPost,
        _toggleLike = toggleLike,
        _toggleSave = toggleSave,
        _toggleRepost = toggleRepost,
        _getComments = getComments,
        _getReplies = getReplies,
        _createComment = createComment,
        _editComment = editComment,
        _deleteComment = deleteComment,
        _toggleCommentLike = toggleCommentLike,
        _watchComments = watchComments,
        super(PostDetailState(postId: postId, myUserId: myUserId));

  final GetPost _getPost;
  final ToggleLike _toggleLike;
  final ToggleSave _toggleSave;
  final ToggleRepost _toggleRepost;
  final GetComments _getComments;
  final GetReplies _getReplies;
  final CreateComment _createComment;
  final EditComment _editComment;
  final DeleteComment _deleteComment;
  final ToggleCommentLike _toggleCommentLike;
  final WatchPostComments _watchComments;

  StreamSubscription<CommentEvent>? _realtime;

  int get _postId => state.postId;

  // ── Loading ────────────────────────────────────────────────────────────

  Future<void> load() async {
    final results = await Future.wait([
      _getPost(_postId),
      _getComments(GetCommentsParams(postId: _postId)),
    ]);
    if (isClosed) return;

    final post = results[0].valueOrNull as Post?;
    if (post == null) {
      emit(state.copyWith(
        status: PostDetailStatus.error,
        failure: results[0].failureOrNull ?? const NotFoundFailure(),
      ));
      return;
    }
    final comments = results[1].valueOrNull as List<Comment>?;
    emit(state.copyWith(
      status: PostDetailStatus.ready,
      post: post,
      comments: comments ?? const [],
      hasMore: (comments?.length ?? 0) >= CommentPolicy.pageSize,
      actionFailure: comments == null ? results[1].failureOrNull : null,
    ));

    _realtime ??= _watchComments(_postId).listen(_onEvent);
  }

  Future<void> refresh() async {
    final results = await Future.wait([
      _getPost(_postId),
      _getComments(GetCommentsParams(postId: _postId)),
    ]);
    if (isClosed) return;
    final post = results[0].valueOrNull as Post?;
    final comments = results[1].valueOrNull as List<Comment>?;
    emit(state.copyWith(
      post: post,
      comments: comments,
      replies: const {},
      expanded: const {},
      hasMore: comments == null
          ? state.hasMore
          : comments.length >= CommentPolicy.pageSize,
      actionFailure: results[1].failureOrNull ?? results[0].failureOrNull,
    ));
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.comments.isEmpty) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getComments(GetCommentsParams(
      postId: _postId,
      beforeId: state.comments.last.id,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, actionFailure: failure)),
      (older) => emit(state.copyWith(
        isLoadingMore: false,
        comments: [...state.comments, ...older.where((c) => !_hasRoot(c.id))],
        hasMore: older.length >= CommentPolicy.pageSize,
      )),
    );
  }

  /// Shows / hides a thread's replies, fetching them the first time.
  Future<void> toggleThread(Comment root) async {
    final expanded = {...state.expanded};
    if (expanded.remove(root.id)) {
      emit(state.copyWith(expanded: expanded));
      return;
    }
    expanded.add(root.id);
    emit(state.copyWith(expanded: expanded));
    if (state.replies[root.id] == null) await loadMoreReplies(root);
  }

  Future<void> loadMoreReplies(Comment root) async {
    if (state.loadingReplies.contains(root.id)) return;
    emit(state.copyWith(loadingReplies: {...state.loadingReplies, root.id}));
    final loaded = state.repliesOf(root.id);
    final result = await _getReplies(GetRepliesParams(
      rootId: root.id,
      afterId: loaded.isEmpty ? null : loaded.last.id,
    ));
    if (isClosed) return;
    final loading = {...state.loadingReplies}..remove(root.id);
    result.fold(
      (failure) => emit(state.copyWith(loadingReplies: loading, actionFailure: failure)),
      (more) {
        final known = state.repliesOf(root.id);
        final merged = [
          ...known,
          ...more.where((r) => !known.any((k) => k.id == r.id)),
        ];
        emit(state.copyWith(
          loadingReplies: loading,
          replies: {...state.replies, root.id: merged},
        ));
      },
    );
  }

  // ── Composer ───────────────────────────────────────────────────────────

  void startReply(Comment comment) =>
      emit(state.copyWith(replyTo: comment, clearEditing: true));

  void cancelReply() => emit(state.copyWith(clearReplyTo: true));

  void startEdit(Comment comment) {
    if (!comment.canEdit(state.myUserId)) return;
    emit(state.copyWith(editing: comment, clearReplyTo: true));
  }

  void cancelEdit() => emit(state.copyWith(clearEditing: true));

  /// Posts a comment / reply, or saves the edit in progress.
  /// Returns true when the composer should clear.
  Future<bool> submit(String text) async {
    if (state.isSending) return false;
    final editing = state.editing;
    final replyTo = state.replyTo;
    emit(state.copyWith(isSending: true, clearActionFailure: true));

    final Result<Comment> result = editing != null
        ? await _editComment(EditCommentParams(comment: editing, body: text))
        : await _createComment(CreateCommentParams(
            postId: _postId,
            body: text,
            parentId: replyTo?.id,
          ));
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(isSending: false, actionFailure: failure));
        return false;
      },
      (comment) {
        emit(state.copyWith(isSending: false, clearReplyTo: true, clearEditing: true));
        if (editing != null) {
          _upsert(comment.copyWith(liked: editing.liked));
        } else {
          _insertNew(comment, expandThread: true);
        }
        return true;
      },
    );
  }

  // ── Comment actions ────────────────────────────────────────────────────

  Future<void> toggleCommentLike(Comment comment) async {
    if (comment.isGone) return;
    final optimistic = comment.copyWith(
      liked: !comment.liked,
      likeCount: comment.liked
          ? (comment.likeCount - 1).clamp(0, 1 << 30)
          : comment.likeCount + 1,
    );
    _upsert(optimistic, keepLiked: false);

    final result = await _toggleCommentLike(comment.id);
    if (isClosed) return;
    result.fold(
      (failure) {
        _upsert(comment, keepLiked: false);
        emit(state.copyWith(actionFailure: failure));
      },
      (r) => _upsert(comment.copyWith(liked: r.liked, likeCount: r.likeCount),
          keepLiked: false),
    );
  }

  Future<void> deleteComment(Comment comment) async {
    final snapshot = state;
    _applyGone(comment);

    final result = await _deleteComment(comment.id);
    if (isClosed) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(snapshot.copyWith(actionFailure: failure));
    }
  }

  /// After a moderator removed a comment via [ModActions].
  void markRemoved(Comment comment) =>
      _upsert(comment.copyWith(moderationStatus: 'removed'));

  // ── Post actions ───────────────────────────────────────────────────────

  Future<void> togglePostLike() => _postAction(
        (p) => p.copyWith(
          liked: !p.liked,
          likes: p.liked ? (p.likes - 1).clamp(0, 1 << 30) : p.likes + 1,
        ),
        (p) => _toggleLike(p),
      );

  Future<void> togglePostSave() => _postAction(
        (p) => p.copyWith(saved: !p.saved),
        (p) => _toggleSave(p),
      );

  Future<void> togglePostRepost() => _postAction(
        (p) => p.copyWith(
          reposted: !p.reposted,
          repostCount: p.reposted
              ? (p.repostCount - 1).clamp(0, 1 << 30)
              : p.repostCount + 1,
        ),
        (p) => _toggleRepost(ToggleRepostParams(post: p)),
      );

  Future<void> _postAction(
    Post Function(Post) preview,
    Future<Result<Post>> Function(Post) action,
  ) async {
    final original = state.post;
    if (original == null) return;
    emit(state.copyWith(post: preview(original)));
    final result = await action(original);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(post: original, actionFailure: failure)),
      (updated) => emit(state.copyWith(post: updated)),
    );
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));

  // ── Realtime ───────────────────────────────────────────────────────────

  void _onEvent(CommentEvent event) {
    switch (event) {
      case CommentUpserted(:final comment):
        {
          final known = _find(comment.id);
          if (known == null) {
            if (!comment.isGone) _insertNew(comment, expandThread: false);
          } else if (!known.isGone && comment.isGone) {
            _applyGone(comment);
          } else {
            _upsert(comment.mergedOnto(known), keepLiked: false);
          }
        }
      case CommentRemoved(:final commentId):
        {
          final known = _find(commentId);
          if (known != null) _drop(known);
        }
    }
  }

  // ── List bookkeeping ───────────────────────────────────────────────────

  bool _hasRoot(int id) => state.comments.any((c) => c.id == id);

  Comment? _find(int id) {
    for (final c in state.comments) {
      if (c.id == id) return c;
    }
    for (final list in state.replies.values) {
      for (final r in list) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  Post? _postWithCount(int delta) {
    final post = state.post;
    if (post == null) return null;
    return post.copyWith(
        replyCount: (post.replyCount + delta).clamp(0, 1 << 30));
  }

  /// A comment we didn't have before (ours just posted, or someone else's
  /// arriving over realtime).
  void _insertNew(Comment comment, {required bool expandThread}) {
    if (_find(comment.id) != null) {
      _upsert(comment);
      return;
    }
    if (comment.isRoot) {
      emit(state.copyWith(
        comments: [comment, ...state.comments],
        post: _postWithCount(1),
      ));
      return;
    }
    final rootId = comment.threadId;
    final replies = {...state.replies};
    final loaded = replies[rootId];
    if (loaded != null || expandThread) {
      replies[rootId] = [...?loaded, comment];
    }
    final comments = [
      for (final c in state.comments)
        c.id == rootId ? c.copyWith(replyCount: c.replyCount + 1) : c,
    ];
    emit(state.copyWith(
      comments: comments,
      replies: replies,
      expanded: expandThread ? {...state.expanded, rootId} : state.expanded,
      post: _postWithCount(1),
    ));
  }

  /// Replaces a known comment in place. [keepLiked] preserves the viewer's
  /// like flag (server rows don't carry it).
  void _upsert(Comment comment, {bool keepLiked = true}) {
    Comment pick(Comment old) =>
        keepLiked ? comment.copyWith(liked: old.liked) : comment;

    if (comment.isRoot) {
      emit(state.copyWith(comments: [
        for (final c in state.comments) c.id == comment.id ? pick(c) : c,
      ]));
      return;
    }
    final rootId = comment.threadId;
    final list = state.replies[rootId];
    if (list == null) return;
    emit(state.copyWith(replies: {
      ...state.replies,
      rootId: [for (final r in list) r.id == comment.id ? pick(r) : r],
    }));
  }

  /// Deleted / removed: roots with replies become placeholders, everything
  /// else disappears.
  void _applyGone(Comment comment) {
    if (comment.isRoot) {
      final hasReplies = comment.replyCount > 0;
      emit(state.copyWith(
        post: _postWithCount(-1),
        comments: hasReplies
            ? [
                for (final c in state.comments)
                  c.id == comment.id
                      ? c.copyWith(
                          deletedAt: comment.deletedAt ?? DateTime.now().toUtc(),
                          clearBody: true,
                        )
                      : c,
              ]
            : state.comments.where((c) => c.id != comment.id).toList(),
      ));
      return;
    }
    _drop(comment, adjustPostCount: true);
  }

  void _drop(Comment comment, {bool adjustPostCount = false}) {
    if (comment.isRoot) {
      emit(state.copyWith(
        comments: state.comments.where((c) => c.id != comment.id).toList(),
        replies: {...state.replies}..remove(comment.id),
      ));
      return;
    }
    final rootId = comment.threadId;
    final list = state.repliesOf(rootId).where((r) => r.id != comment.id).toList();
    emit(state.copyWith(
      post: adjustPostCount ? _postWithCount(-1) : null,
      replies: {...state.replies, rootId: list},
      comments: [
        for (final c in state.comments)
          c.id == rootId
              ? c.copyWith(replyCount: (c.replyCount - 1).clamp(0, 1 << 30))
              : c,
      ],
    ));
  }

  @override
  Future<void> close() async {
    await _realtime?.cancel();
    return super.close();
  }
}
