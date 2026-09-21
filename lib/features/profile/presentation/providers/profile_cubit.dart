import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/usecases/usecase.dart';
import 'package:mint/features/profile/domain/entities/profile.dart';
import 'package:mint/features/profile/domain/usecases/apply_for_osint.dart';
import 'package:mint/features/profile/domain/usecases/get_profile.dart';
import 'package:mint/features/profile/domain/usecases/update_profile.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.profile,
    this.application,
    this.isLoading = false,
    this.isSubmitting = false,
    this.failure,
    this.loadedForUserId,
  });

  final Profile? profile;
  final OsintApplication? application;
  final bool isLoading;
  final bool isSubmitting;
  final Failure? failure;
  final String? loadedForUserId;

  bool get canPublishStories => profile?.role.canPublishStories ?? false;
  bool get isAdmin => profile?.role.isAdmin ?? false;

  ProfileState copyWith({
    Profile? profile,
    OsintApplication? application,
    bool? isLoading,
    bool? isSubmitting,
    Failure? failure,
    String? loadedForUserId,
    bool clearFailure = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      application: application ?? this.application,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      loadedForUserId: loadedForUserId ?? this.loadedForUserId,
    );
  }

  @override
  List<Object?> get props => [
        profile,
        application,
        isLoading,
        isSubmitting,
        failure,
        loadedForUserId,
      ];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required String? initialUserId, // 1. Add this
    required GetProfile getProfile,
    required UpdateProfile updateProfile,
    required ApplyForOsint applyForOsint,
    required GetMyApplication getMyApplication,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        _applyForOsint = applyForOsint,
        _getMyApplication = getMyApplication,
        super(const ProfileState()) {
    // 2. Trigger the initial load immediately on creation
    syncWithUser(initialUserId);
  }

  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;
  final ApplyForOsint _applyForOsint;
  final GetMyApplication _getMyApplication;

  /// Called by the auth listener whenever the session changes. Passing null
  /// clears state on sign-out so no stale profile leaks into the next session.
  Future<void> syncWithUser(String? userId) async {
    if (userId == null) {
      emit(const ProfileState()); // Clears everything
      return;
    }
    if (userId == state.loadedForUserId && state.profile != null) return;

    emit(state.copyWith(loadedForUserId: userId));
    await load(userId);
  }

  Future<void> load(String userId) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _getProfile(userId);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (profile) => emit(state.copyWith(isLoading: false, profile: profile)),
    );
  }

  Future<bool> updateUsername(String username) async {
    final id = state.profile?.id;
    if (id == null) return false;

    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _updateProfile(
      UpdateProfileParams(userId: id, username: username),
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, failure: failure));
        return false;
      },
      (profile) {
        emit(state.copyWith(isLoading: false, profile: profile));
        return true;
      },
    );
  }

  Future<void> loadApplication() async {
    final result = await _getMyApplication(const NoParams());
    emit(state.copyWith(application: result.valueOrNull));
  }

  Future<bool> applyForOsint(OsintApplicationParams params) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _applyForOsint(params);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSubmitting: false));
        await loadApplication();
        return true;
      },
    );
  }
}
