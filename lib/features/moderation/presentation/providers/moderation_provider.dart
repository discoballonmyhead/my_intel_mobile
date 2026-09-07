import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/community_note.dart';
import '../../domain/usecases/moderation_usecases.dart';

class ModerationProvider extends ChangeNotifier {
  ModerationProvider({
    required GetPostModeration getPostModeration,
    required SubmitNote submitNote,
    required GetOpenClaims getOpenClaims,
    required ResolveClaim resolveClaim,
    required SubmitFeedback submitFeedback,
  })  : _getPostModeration = getPostModeration,
        _submitNote = submitNote,
        _getOpenClaims = getOpenClaims,
        _resolveClaim = resolveClaim,
        _submitFeedback = submitFeedback;

  final GetPostModeration _getPostModeration;
  final SubmitNote _submitNote;
  final GetOpenClaims _getOpenClaims;
  final ResolveClaim _resolveClaim;
  final SubmitFeedback _submitFeedback;

  final Map<int, PostModeration> _byPost = {};
  List<Claim> _openClaims = const [];
  bool _loading = false;
  Failure? _failure;

  List<Claim> get openClaims => _openClaims;
  bool get loading => _loading;
  Failure? get failure => _failure;

  PostModeration? forPost(int postId) => _byPost[postId];

  Future<void> loadForPost(int postId) async {
    _loading = true;
    notifyListeners();

    final result = await _getPostModeration(postId);
    result.fold(
      (failure) => _failure = failure,
      (moderation) => _byPost[postId] = moderation,
    );

    _loading = false;
    notifyListeners();
  }

  Future<bool> submitNote(int postId, String body, NoteStance stance) async {
    final result = await _submitNote(
      SubmitNoteParams(postId: postId, body: body, stance: stance),
    );
    final failure = result.failureOrNull;
    if (failure != null) {
      _failure = failure;
      notifyListeners();
      return false;
    }
    // Refetch: inserting a note can trip the claim threshold trigger, so the
    // claim state may have changed as a side effect of this write.
    await loadForPost(postId);
    return true;
  }

  Future<void> loadOpenClaims() async {
    _loading = true;
    notifyListeners();

    final result = await _getOpenClaims(const NoParams());
    result.fold(
      (failure) => _failure = failure,
      (claims) => _openClaims = claims,
    );

    _loading = false;
    notifyListeners();
  }

  Future<bool> resolveClaim(int claimId, String status, {String? note}) async {
    final result = await _resolveClaim(ResolveClaimParams(
      claimId: claimId,
      status: status,
      resolutionNote: note,
    ));
    final failure = result.failureOrNull;
    if (failure != null) {
      _failure = failure;
      notifyListeners();
      return false;
    }
    _openClaims = _openClaims.where((c) => c.id != claimId).toList();
    notifyListeners();
    return true;
  }

  Future<bool> submitFeedback(
    Map<String, dynamic> ratings, {
    String? comment,
  }) async {
    final result = await _submitFeedback(
      SubmitFeedbackParams(ratings: ratings, comment: comment),
    );
    final failure = result.failureOrNull;
    if (failure != null) {
      _failure = failure;
      notifyListeners();
      return false;
    }
    return true;
  }
}
