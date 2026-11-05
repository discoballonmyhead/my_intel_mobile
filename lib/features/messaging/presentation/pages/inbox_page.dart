import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/mint_logo.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/domain/usecases/search_profiles.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/conversation.dart';
import '../cubits/inbox_cubit.dart';
import '../widgets/messaging_ui.dart';

/// Conversations whose name or last message contains [query], ignoring case.
List<InboxEntry> searchInbox(
    List<InboxEntry> entries, String query, String? myUserId) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final e in entries)
      if (e.displayName.toLowerCase().contains(q) ||
          e.preview(myUserId).toLowerCase().contains(q))
        e,
  ];
}

/// The Messages tab: search, Chats / Groups tabs and the conversation list.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _groups = false;
  bool _searching = false;
  final _searchKey = GlobalKey(debugLabel: 'inbox-search');

  // People results for the search, from the same lookup New message uses.
  List<Profile> _people = const [];
  Timer? _debounce;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && !_searching) setState(() => _searching = true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _people = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final token = ++_token;
      final result =
          await sl<SearchProfiles>()(SearchProfilesParams(query: value.trim()));
      if (!mounted || token != _token) return;
      final me = context.read<InboxCubit>().state.userId;
      setState(() => _people = (result.valueOrNull ?? const <Profile>[])
          .where((p) => p.id != me)
          .take(5)
          .toList());
    });
  }

  void _cancelSearch() {
    _focus.unfocus();
    _query.clear();
    setState(() {
      _searching = false;
      _people = const [];
    });
  }

  Future<void> _openPerson(Profile person) async {
    final id = await context.read<InboxCubit>().openDirect(person.id);
    if (id != null && mounted) unawaited(context.push(AppRoutes.chatFor(id)));
  }

  Future<void> _showActions(InboxEntry entry) async {
    final cubit = context.read<InboxCubit>();
    final choice = await showChoiceSheet(context, actions: [
      SheetAction(entry.isMuted ? 'Unmute' : 'Mute',
          icon: entry.isMuted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined),
      const SheetAction('Delete conversation',
          icon: Icons.delete_outline_rounded, destructive: true),
    ]);
    if (!mounted || choice == null) return;
    if (choice == 0) {
      await cubit.toggleMute(entry);
      return;
    }
    final ok = await showConfirmSheet(
      context,
      title: 'Delete conversation?',
      body: entry.isGroup
          ? 'It’s removed from your inbox. Others in the group keep their copy.'
          : 'It’s removed from your inbox. ${entry.displayName} still has '
              'their copy.',
      actions: const [SheetAction('Delete', destructive: true)],
    );
    if (ok == 0) await cubit.deleteConversation(entry.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<InboxCubit, InboxState>(
          listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
          listener: (context, state) {
            if (state.status == InboxStatus.ready && state.failure != null) {
              AppDialogs.snack(context, state.failure!.message);
              context.read<InboxCubit>().clearFailure();
            }
          },
          builder: (context, state) {
            final cubit = context.read<InboxCubit>();
            return ContentColumn(
              padded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_searching) _title(context),
                  // Keyed so the field keeps focus when the title hides.
                  KeyedSubtree(key: _searchKey, child: _searchBar(context)),
                  if (_searching)
                    Expanded(child: _results(context, state))
                  else ...[
                    _Tabs(
                      groups: _groups,
                      chatsUnread: _unread(state, groups: false),
                      groupsUnread: _unread(state, groups: true),
                      onChanged: (g) => setState(() => _groups = g),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: cubit.refresh,
                        child: _list(context, state, cubit),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _unread(InboxState state, {required bool groups}) => state.entries
      .where((e) => e.isGroup == groups && !e.isMuted)
      .fold(0, (sum, e) => sum + e.unreadCount);

  /// The MINT logo with New message on the right, like the Feed header.
  Widget _title(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const MintLogo(height: 30, animate: false),
          Positioned(
            right: 6,
            child: IconButton(
              tooltip: 'New message',
              icon: const Icon(Icons.edit_square),
              onPressed: () => context.push(AppRoutes.newMessage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(21),
      borderSide:
          _searching ? BorderSide(color: palette.border) : BorderSide.none,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, _searching ? 10 : 2, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _query,
              focusNode: _focus,
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              style: inter(15.5, color: onSurface),
              decoration: InputDecoration(
                hintText: 'Search messages and people',
                hintStyle: inter(15.5, color: palette.muted),
                prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: Icon(Icons.cancel_rounded, color: palette.muted),
                        onPressed: () {
                          _query.clear();
                          _onQuery('');
                        },
                      ),
                filled: true,
                fillColor: _searching
                    ? Theme.of(context).colorScheme.surface
                    : palette.surface2,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ),
          if (_searching)
            TextButton(
              onPressed: _cancelSearch,
              style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  textStyle: inter(16, weight: FontWeight.w500)),
              child: const Text('Cancel'),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, InboxState state, InboxCubit cubit) {
    switch (state.status) {
      case InboxStatus.idle || InboxStatus.loading:
        return const _InboxSkeleton();
      case InboxStatus.error:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            SoftMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Can’t load messages',
              body: 'Check your connection and try again.',
              action: 'Try again',
              onAction: cubit.load,
            ),
          ],
        );
      case InboxStatus.ready:
        break;
    }
    final entries = state.entries.where((e) => e.isGroup == _groups).toList();
    if (entries.isEmpty && !_groups) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          SoftMessage(
            icon: Icons.forum_rounded,
            title: 'No messages yet',
            body: 'Start a conversation with anyone on MINT.',
            action: 'New message',
            filledAction: true,
            onAction: () => context.push(AppRoutes.newMessage),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in entries)
          InboxRow(
            entry: entry,
            myUserId: state.userId,
            onTap: () => context.push(AppRoutes.chatFor(entry.conversationId)),
            onLongPress: () => _showActions(entry),
          ),
        if (_groups)
          _NewGroupCard(
              onTap: () => context.push('${AppRoutes.newMessage}?group=1')),
      ],
    );
  }

  Widget _results(BuildContext context, InboxState state) {
    final palette = context.palette;
    final q = _query.text.trim();
    if (q.isEmpty) return const SizedBox.shrink();
    final hits = searchInbox(state.entries, q, state.userId);
    if (hits.isEmpty && _people.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 90),
        SoftMessage(
          icon: Icons.search_off_rounded,
          title: 'No results for “$q”',
          body: 'Try a name or a word from the message.',
        ),
      ]);
    }
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(text,
              style: inter(13, weight: FontWeight.w600, color: palette.muted)),
        );
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_people.isNotEmpty) ...[
          label('People'),
          for (final p in _people)
            _PersonRow(profile: p, onTap: () => _openPerson(p)),
        ],
        if (hits.isNotEmpty) ...[
          label('Messages'),
          for (final e in hits)
            InboxRow(
              entry: e,
              myUserId: state.userId,
              highlight: q,
              onTap: () => context.push(AppRoutes.chatFor(e.conversationId)),
            ),
        ],
      ],
    );
  }
}

/// Chats / Groups, half the width each, with an underline and unread counts.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.groups,
    required this.chatsUnread,
    required this.groupsUnread,
    required this.onChanged,
  });

  final bool groups;
  final int chatsUnread;
  final int groupsUnread;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget tab(String label, bool value, int unread) {
      final on = groups == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            onTap: on ? null : () => onChanged(value),
            child: SizedBox(
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: inter(15,
                              weight: on ? FontWeight.w600 : FontWeight.w400,
                              color: on ? onSurface : palette.muted)),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        _CountPill(count: unread),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 2.5,
                    width: on ? 56 : 0,
                    decoration: BoxDecoration(
                        color: onSurface,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(children: [
        tab('Chats', false, chatsUnread),
        tab('Groups', true, groupsUnread),
      ]),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? palette.muted : palette.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: inter(12, weight: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// One conversation: avatar, name, last message, time and unread count.
class InboxRow extends StatelessWidget {
  const InboxRow({
    required this.entry,
    required this.myUserId,
    required this.onTap,
    this.onLongPress,
    this.highlight,
    super.key,
  });

  final InboxEntry entry;
  final String? myUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Bolds this text inside the last message (search results).
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final unread = entry.hasUnread;
    final preview = entry.preview(myUserId);
    final previewStyle = inter(14.5, color: unread ? onSurface : palette.muted);
    final attachment = preview == 'Attachment' || preview == 'You: Attachment';

    return Semantics(
      identifier: 'inbox-row',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: [
              entry.isGroup
                  ? GroupAvatar(names: [entry.displayName, ..._otherInitials()])
                  : UserAvatar(
                      name: entry.displayName,
                      radius: 26,
                      icon: entry.otherUserId == null
                          ? Icons.person_off_outlined
                          : null,
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: inter(16,
                                  weight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: onSurface)),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.lastActivityAt.timeAgo,
                            style: inter(13,
                                color: unread && !entry.isMuted
                                    ? palette.accent
                                    : palette.muted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (attachment) ...[
                          Icon(Icons.attach_file_rounded,
                              size: 16, color: palette.muted),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: highlight == null
                              ? Text(preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: previewStyle.copyWith(
                                      fontStyle: entry.lastMessageDeleted
                                          ? FontStyle.italic
                                          : null))
                              : _Highlighted(
                                  text: preview,
                                  match: highlight!,
                                  style: previewStyle,
                                  matchColor: onSurface,
                                ),
                        ),
                        if (entry.isMuted)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.notifications_off_outlined,
                                size: 17, color: palette.muted),
                          ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          _CountPill(
                              count: entry.unreadCount, muted: entry.isMuted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A second initial for the group avatar: the last sender is unknown here,
  /// so use the next letter of the title for variety.
  List<String> _otherInitials() {
    final words = entry.displayName.split(RegExp(r'\s+'));
    return [words.length > 1 ? words[1] : entry.displayName];
  }
}

class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.text,
    required this.match,
    required this.style,
    required this.matchColor,
  });

  final String text;
  final String match;
  final TextStyle style;
  final Color matchColor;

  @override
  Widget build(BuildContext context) {
    final i = text.toLowerCase().indexOf(match.toLowerCase());
    if (i < 0) {
      return Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text.rich(
      TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(
            text: text.substring(i, i + match.length),
            style: TextStyle(fontWeight: FontWeight.w600, color: matchColor)),
        TextSpan(text: text.substring(i + match.length)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

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
            UserAvatar(name: profile.username, radius: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.username,
                      style:
                          inter(16, weight: FontWeight.w500, color: onSurface)),
                  Text(profile.role.displayName,
                      style: inter(13, color: palette.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewGroupCard extends StatelessWidget {
  const _NewGroupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.group_add_rounded, color: palette.accent),
                const SizedBox(width: 14),
                Text('New group',
                    style: inter(16,
                        weight: FontWeight.w500, color: palette.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.palette.surface2;
    Widget bar(double w) => Container(
          width: w,
          height: 12,
          decoration: BoxDecoration(
              color: block, borderRadius: BorderRadius.circular(6)),
        );
    const widths = <(double, double)>[
      (140, 230),
      (110, 200),
      (160, 250),
      (120, 180)
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final (a, b) in widths)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            child: Row(
              children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(color: block, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(a), const SizedBox(height: 12), bar(b)],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
