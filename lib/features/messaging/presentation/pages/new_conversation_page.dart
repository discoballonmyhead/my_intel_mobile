import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../cubits/inbox_cubit.dart';
import '../cubits/new_conversation_cubit.dart';

/// New message: pick one person to chat with, or tap New group to pick
/// several and then name the group. In add mode it adds people to a group.
class NewConversationPage extends StatefulWidget {
  const NewConversationPage({this.startAsGroup = false, super.key});

  /// Opened from the Groups tab: go straight to picking people for a group.
  final bool startAsGroup;

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  late bool _group = widget.startAsGroup;
  bool _naming = false;
  final _search = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  /// People you've chatted with one to one, from the inbox.
  List<Profile> _suggested(NewConversationState state) {
    final entries = context.read<InboxCubit>().state.entries;
    return [
      for (final e in entries)
        if (!e.isGroup &&
            e.otherProfile != null &&
            !state.excludedUserIds.contains(e.otherProfile!.id))
          e.otherProfile!,
    ];
  }

  void _back(NewConversationState state) {
    if (_naming) {
      setState(() => _naming = false);
    } else if (_group && !widget.startAsGroup && !state.isAddMode) {
      setState(() => _group = false);
      for (final p in List.of(state.selected)) {
        context.read<NewConversationCubit>().toggle(p);
      }
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewConversationCubit, NewConversationState>(
      listenWhen: (a, b) =>
          a.resultConversationId != b.resultConversationId ||
          (b.failure != null && a.failure != b.failure),
      listener: (context, state) {
        final id = state.resultConversationId;
        if (id != null) {
          context.read<InboxCubit>().refresh();
          if (state.isAddMode) {
            context.pop();
          } else {
            context.pushReplacement(AppRoutes.chatFor(id));
          }
          return;
        }
        if (state.failure != null) {
          AppDialogs.snack(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final cubit = context.read<NewConversationCubit>();
        final picking = _group || state.isAddMode;
        final title = state.isAddMode
            ? 'Add people'
            : _group
                ? 'New group'
                : 'New message';
        final action = state.isAddMode
            ? 'Add'
            : _naming
                ? 'Create'
                : _group
                    ? 'Next'
                    : null;
        final actionOn = _naming
            ? _name.text.trim().isNotEmpty && state.canSubmit
            : state.selected.isNotEmpty && !state.isSubmitting;

        return PopScope(
          canPop: !_naming && !(_group && !widget.startAsGroup),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back(state);
          },
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                onPressed: () => _back(state),
              ),
              title: Text(title,
                  style: inter(17,
                      weight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
              actions: [
                if (action != null)
                  TextButton(
                    onPressed: !actionOn
                        ? null
                        : () {
                            if (_group && !_naming && !state.isAddMode) {
                              setState(() => _naming = true);
                            } else {
                              cubit.submit();
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: context.palette.accent,
                      textStyle: inter(16, weight: FontWeight.w600),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(action),
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: ContentColumn(
              padded: false,
              child: _naming
                  ? _nameStep(context, state, cubit)
                  : _pickStep(context, state, cubit, picking),
            ),
          ),
        );
      },
    );
  }

  Widget _pickStep(BuildContext context, NewConversationState state,
      NewConversationCubit cubit, bool picking) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final query = state.query.trim();
    final people = query.isEmpty ? _suggested(state) : state.results;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
                color: palette.surface2,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (picking && state.selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in state.selected)
                          _Chip(profile: p, onRemove: () => cubit.toggle(p)),
                      ],
                    ),
                  ),
                TextField(
                  controller: _search,
                  autofocus: !picking,
                  onChanged: cubit.search,
                  style: inter(15.5, color: onSurface),
                  decoration: InputDecoration(
                    hintText: picking ? 'Search people' : 'To: Search people',
                    hintStyle: inter(15.5, color: palette.muted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!picking)
          InkWell(
            onTap: () => setState(() => _group = true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(Icons.group_add_rounded, color: palette.accent),
                  ),
                  const SizedBox(width: 14),
                  Text('New group',
                      style: inter(16,
                          weight: FontWeight.w500, color: palette.accent)),
                ],
              ),
            ),
          ),
        if (state.isSearching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else ...[
          if (people.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(query.isEmpty ? 'Suggested' : 'People',
                  style: inter(13,
                      weight: FontWeight.w600, color: palette.muted)),
            ),
          if (people.isEmpty && query.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: SoftMessage(
                icon: Icons.search_off_rounded,
                title: 'No one found',
                body: 'Try a different username.',
              ),
            ),
          if (people.isEmpty && query.isEmpty && !picking)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text('Search for anyone on MINT by their username.',
                  textAlign: TextAlign.center,
                  style: inter(14.5, color: palette.muted)),
            ),
          for (final p in people)
            _PersonRow(
              profile: p,
              selected: picking ? state.isSelected(p) : null,
              onTap: () {
                cubit.toggle(p);
                if (!picking) cubit.submit();
              },
            ),
        ],
      ],
    );
  }

  Widget _nameStep(BuildContext context, NewConversationState state,
      NewConversationCubit cubit) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      children: [
        SoftField(
          label: 'Group name',
          controller: _name,
          autofocus: true,
          capitalization: TextCapitalization.words,
          hint: 'e.g. Mumbai Floods Desk',
          onChanged: (v) {
            cubit.setGroupTitle(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        SectionLabel('${state.selected.length + 1} members'),
        SettingsGroup([
          const SettingsRow(title: 'You', value: 'Admin'),
          for (final p in state.selected)
            SettingsRow(title: p.username, subtitle: p.role.displayName),
        ]),
        const SizedBox(height: 8),
        PillButton(
          label: 'Create group',
          loading: state.isSubmitting,
          onPressed: _name.text.trim().isEmpty ? null : cubit.submit,
        ),
        const SizedBox(height: 10),
        Text('You can rename the group and add people later.',
            textAlign: TextAlign.center,
            style: inter(13, color: palette.muted)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.profile, required this.onRemove});

  final Profile profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(name: profile.username, radius: 12),
          const SizedBox(width: 6),
          Text(profile.username,
              style: inter(14,
                  weight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 18, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(
      {required this.profile, required this.onTap, this.selected});

  final Profile profile;
  final VoidCallback onTap;

  /// Null when not picking (one tap opens the chat).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            UserAvatar(name: profile.username, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.username,
                      style: inter(16,
                          weight: FontWeight.w500, color: onSurface)),
                  Text(profile.role.displayName,
                      style: inter(13, color: palette.muted)),
                ],
              ),
            ),
            if (selected != null)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected! ? palette.accent : null,
                  border: selected!
                      ? null
                      : Border.all(color: palette.border, width: 2),
                ),
                child: selected!
                    ? const Icon(Icons.check_rounded,
                        size: 17, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
