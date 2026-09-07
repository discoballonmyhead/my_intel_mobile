import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/apply_for_osint.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';

/// Owns the signed-in user's profile row. Kept separate from AuthProvider:
/// auth answers "who is signed in", this answers "what is their role, score
/// and username" — which the feed, composer and admin gate all read.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    required GetProfile getProfile,
    required UpdateProfile updateProfile,
    required ApplyForOsint applyForOsint,
    required GetMyApplication getMyApplication,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        _applyForOsint = applyForOsint,
        _getMyApplication = getMyApplication;

  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;
  final ApplyForOsint _applyForOsint;
  final GetMyApplication _getMyApplication;

  Profile? _profile;
  OsintApplication? _application;
  bool _loading = false;
  Failure? _failure;
  String? _loadedForUserId;

  Profile? get profile => _profile;
  OsintApplication? get application => _application;
  bool get loading => _loading;
  Failure? get failure => _failure;
  bool get canPublishStories => _profile?.role.canPublishStories ?? false;
  bool get isAdmin => _profile?.role.isAdmin ?? false;

  /// Called by the auth listener whenever the session changes. Passing null
  /// clears state on sign-out so no stale profile leaks into the next session.
  Future<void> syncWithUser(String? userId) async {
    if (userId == null) {
      _profile = null;
      _application = null;
      _loadedForUserId = null;
      notifyListeners();
      return;
    }
    if (userId == _loadedForUserId && _profile != null) return;
    _loadedForUserId = userId;
    await load(userId);
  }

  Future<void> load(String userId) async {
    _loading = true;
    _failure = null;
    notifyListeners();

    final result = await _getProfile(userId);
    result.fold(
      (failure) => _failure = failure,
      (profile) => _profile = profile,
    );

    _loading = false;
    notifyListeners();
  }

  Future<bool> updateUsername(String username) async {
    final id = _profile?.id;
    if (id == null) return false;

    final result = await _updateProfile(
      UpdateProfileParams(userId: id, username: username),
    );
    return result.fold(
      (failure) {
        _failure = failure;
        notifyListeners();
        return false;
      },
      (profile) {
        _profile = profile;
        _failure = null;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> loadApplication() async {
    final result = await _getMyApplication(const NoParams());
    _application = result.valueOrNull;
    notifyListeners();
  }

  Future<bool> applyForOsint(OsintApplicationParams params) async {
    final result = await _applyForOsint(params);
    final failure = result.failureOrNull;
    if (failure != null) {
      _failure = failure;
      notifyListeners();
      return false;
    }
    await loadApplication();
    return true;
  }
}
