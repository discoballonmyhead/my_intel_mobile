import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/domain/usecases/search_profiles.dart';
import '../../domain/usecases/messaging_usecases.dart';

/// Route arguments for [NewConversationCubit] (a get_it factory param must
/// have an exact, non-nullable runtime type).
class NewConversationArgs {
  const NewConversationArgs({this.addToConversationId});

  /// Set to add members to an existing group instead of starting a chat.
  final String? addToConversationId;
}

class NewConversationState extends Equatable {
  const NewConversationState({
    this.addToConversationId,
    this.excludedUserIds = const {},
    this.query = '',
    this.results = const [],
    this.selected = const [],
    this.groupTitle = '',
    this.isSearching = false,
    this.isSubmitting = false,
    this.failure,
    this.resultConversationId,
  });

  /// Set when adding people to an existing group instead of starting a chat.
  final String? addToConversationId;
  final Set<String> excludedUserIds;
  final String query;
  final List<Profile> results;
  final List<Profile> selected;
  final String groupTitle;
  final bool isSearching;
  final bool isSubmitting;
  final Failure? failure;

  /// Set on success; the page navigates to it.
  final String? resultConversationId;

  bool get isAddMode => addToConversationId != null;
  bool get isGroup => isAddMode || selected.length > 1;
  bool get canSubmit => selected.isNotEmpty && !isSubmitting;
  bool isSelected(Profile p) => selected.any((s) => s.id == p.id);

  NewConversationState copyWith({
    Set<String>? excludedUserIds,
    String? query,
    List<Profile>? results,
    List<Profile>? selected,
    String? groupTitle,
    bool? isSearching,
    bool? isSubmitting,
    Failure? failure,
    String? resultConversationId,
    bool clearFailure = false,
  }) {
    return NewConversationState(
      addToConversationId: addToConversationId,
      excludedUserIds: excludedUserIds ?? this.excludedUserIds,
      query: query ?? this.query,
      results: results ?? this.results,
      selected: selected ?? this.selected,
      groupTitle: groupTitle ?? this.groupTitle,
      isSearching: isSearching ?? this.isSearching,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      resultConversationId: resultConversationId ?? this.resultConversationId,
    );
  }

  @override
  List<Object?> get props => [
        addToConversationId,
        excludedUserIds,
        query,
        results,
        selected,
        groupTitle,
        isSearching,
        isSubmitting,
        failure,
        resultConversationId,
      ];
}

/// People picker for a new DM / group, or for adding members to a group.
/// One person + no title opens (or reuses) a DM; more makes a group.
class NewConversationCubit extends Cubit<NewConversationState> {
  NewConversationCubit({
    required String? myUserId,
    required String? addToConversationId,
    required SearchProfiles searchProfiles,
    required OpenDirectConversation openDirect,
    required CreateGroupConversation createGroup,
    required AddGroupMembers addMembers,
    required GetConversation getConversation,
  })  : _myUserId = myUserId,
        _searchProfiles = searchProfiles,
        _openDirect = openDirect,
        _createGroup = createGroup,
        _addMembers = addMembers,
        _getConversation = getConversation,
        super(NewConversationState(
          addToConversationId: addToConversationId,
          excludedUserIds: {if (myUserId != null) myUserId},
        )) {
    if (addToConversationId != null) _loadExistingMembers(addToConversationId);
  }

  final String? _myUserId;
  final SearchProfiles _searchProfiles;
  final OpenDirectConversation _openDirect;
  final CreateGroupConversation _createGroup;
  final AddGroupMembers _addMembers;
  final GetConversation _getConversation;

  Timer? _debounce;
  int _searchToken = 0;

  Future<void> _loadExistingMembers(String conversationId) async {
    final result = await _getConversation(conversationId);
    if (isClosed) return;
    final conversation = result.valueOrNull;
    if (conversation == null) return;
    emit(state.copyWith(excludedUserIds: {
      ...state.excludedUserIds,
      ...conversation.participants.map((p) => p.userId),
    }));
  }

  void search(String query) {
    emit(state.copyWith(query: query, clearFailure: true));
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      emit(state.copyWith(results: const [], isSearching: false));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(query));
  }

  Future<void> _run(String query) async {
    final token = ++_searchToken;
    emit(state.copyWith(isSearching: true));
    final result = await _searchProfiles(SearchProfilesParams(query: query));
    if (isClosed || token != _searchToken) return;
    result.fold(
      (failure) => emit(state.copyWith(isSearching: false, failure: failure)),
      (profiles) => emit(state.copyWith(
        isSearching: false,
        results: profiles
            .where((p) => !state.excludedUserIds.contains(p.id))
            .toList(),
      )),
    );
  }

  void toggle(Profile profile) {
    final selected = state.isSelected(profile)
        ? state.selected.where((p) => p.id != profile.id).toList()
        : [...state.selected, profile];
    emit(state.copyWith(selected: selected));
  }

  void setGroupTitle(String title) => emit(state.copyWith(groupTitle: title));

  Future<void> submit() async {
    if (!state.canSubmit || _myUserId == null) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final ids = state.selected.map((p) => p.id).toList();
    final addTo = state.addToConversationId;

    if (addTo != null) {
      final result = await _addMembers(
          MembersParams(conversationId: addTo, userIds: ids));
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
        (_) => emit(state.copyWith(
            isSubmitting: false, resultConversationId: addTo)),
      );
      return;
    }

    final result = ids.length == 1 && state.groupTitle.trim().isEmpty
        ? await _openDirect(ids.first)
        : await _createGroup(
            CreateGroupParams(title: state.groupTitle, memberIds: ids));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
      (id) => emit(state.copyWith(isSubmitting: false, resultConversationId: id)),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
