import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/photo_viewer.dart';
import '../../../feed/presentation/widgets/post_attachments.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../../e2ee/presentation/widgets/e2ee_widgets.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../cubits/chat_cubit.dart';
import '../cubits/inbox_cubit.dart';
import '../widgets/messaging_ui.dart';

/// Every attachment in the loaded part of the thread, newest first.
List<MessageAttachment> sharedAttachments(List<Message> messages) => [
      for (final m in messages)
        if (!m.isDeleted) ...m.attachments,
    ];

/// Chat info (1:1) or group info: who it's with, mute, shared media, and the
/// member list with add / remove / leave for groups.
class ConversationInfoPage extends StatelessWidget {
  const ConversationInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final conversation = state.conversation;
        if (conversation == null) return const Scaffold();
        return conversation.isGroup
            ? _GroupInfo(state: state, conversation: conversation)
            : _DirectInfo(state: state, conversation: conversation);
      },
    );
  }
}

Future<void> _mute(BuildContext context, Conversation conversation) async {
  final cubit = context.read<ChatCubit>();
  if (conversation.isMuted) {
    await cubit.muteFor(null);
    if (context.mounted) unawaited(context.read<InboxCubit>().refresh());
    return;
  }
  const options = [
    ('For 1 hour', Duration(hours: 1)),
    ('For 8 hours', Duration(hours: 8)),
    ('For 1 week', Duration(days: 7)),
    ('Until I turn it back on', Duration(days: 365 * 100)),
  ];
  final pick = await showChoiceSheet(
    context,
    header: Builder(builder: (sheet) {
      final onSurface = Theme.of(sheet).colorScheme.onSurface;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mute notifications',
              style: inter(19, weight: FontWeight.w600, color: onSurface)),
          const SizedBox(height: 4),
          Text('You’ll still get messages, just no alerts.',
              style: inter(14, color: sheet.palette.muted)),
        ],
      );
    }),
    actions: [for (final (label, _) in options) SheetAction(label)],
  );
  if (pick == null) return;
  await cubit.muteFor(options[pick].$2);
  if (context.mounted) unawaited(context.read<InboxCubit>().refresh());
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.children, this.action});

  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: softAppBar(context, '', actions: [
        if (action != null) action!,
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: children,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.avatar, required this.title, this.subtitle});

  final Widget avatar;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Center(child: avatar),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: inter(20, weight: FontWeight.w600, color: onSurface)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: inter(13.5, color: context.palette.muted)),
        ],
        const SizedBox(height: 22),
      ],
    );
  }
}

/// Group members with their picture and role; Admin on the right.
class _Members extends StatelessWidget {
  const _Members(
      {required this.members, required this.myUserId, required this.onTap});

  final List<Participant> members;
  final String? myUserId;
  final ValueChanged<Participant> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < members.length; i++) ...[
              _row(members[i], palette, onSurface),
              if (i < members.length - 1)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 64,
                    endIndent: 16,
                    color: palette.border.withValues(alpha: 0.7)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Participant p, AppPalette palette, Color onSurface) {
    final me = p.userId == myUserId;
    final role = p.profile?.role.displayName;
    return InkWell(
      onTap: me ? null : () => onTap(p),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            UserAvatar(name: p.displayName, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(me ? 'You' : p.displayName,
                      style: inter(16, color: onSurface)),
                  if (role != null)
                    Text(role, style: inter(13, color: palette.muted)),
                ],
              ),
            ),
            if (p.role.canManage)
              Text('Group admin', style: inter(14, color: palette.muted)),
          ],
        ),
      ),
    );
  }
}

/// Three soft square buttons under the header.
class _Actions extends StatelessWidget {
  const _Actions({required this.items});

  final List<(IconData, String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: items[i].$3,
                child: SizedBox(
                  height: 66,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, color: palette.accent),
                      const SizedBox(height: 6),
                      Text(items[i].$2, style: inter(13, color: onSurface)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (attachments.isEmpty) return const SizedBox(height: 8);
    final visual =
        attachments.where((a) => a.isImage || a.isVideo).take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: SectionLabel('Photos, videos and files')),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SharedMediaPage(attachments: attachments))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 6, 8),
                child: Text('See all',
                    style: inter(13,
                        weight: FontWeight.w500, color: palette.accent)),
              ),
            ),
          ],
        ),
        if (visual.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: i < visual.length
                        ? _MediaCell(
                            attachment: visual[i], all: attachments, radius: 12)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _MediaCell extends StatelessWidget {
  const _MediaCell(
      {required this.attachment, required this.all, this.radius = 0});

  final MessageAttachment attachment;
  final List<MessageAttachment> all;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photos = all.where((a) => a.isImage).map((a) => a.url).toList();
    return GestureDetector(
      onTap: () {
        if (attachment.isImage) {
          PhotoViewer.open(context, photos,
              index: photos.indexOf(attachment.url));
        } else {
          showVideoPlayer(context, attachment.url);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: attachment.isImage
            ? CachedNetworkImage(
                imageUrl: attachment.url,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(color: palette.surface2),
                errorWidget: (_, __, ___) => ColoredBox(
                    color: palette.surface2,
                    child: Icon(Icons.broken_image_outlined,
                        color: palette.muted)),
              )
            : ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black87),
                  ),
                ),
              ),
      ),
    );
  }
}

class _DirectInfo extends StatelessWidget {
  const _DirectInfo({required this.state, required this.conversation});

  final ChatState state;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatCubit>();
    final other = conversation.other(state.myUserId);
    final name = state.title;
    return _Scaffold(children: [
      _Header(
        avatar: UserAvatar(name: name, radius: 40),
        title: name,
        subtitle: other?.profile?.role.displayName,
      ),
      _Actions(items: [
        (
          Icons.person_outline_rounded,
          'Profile',
          other == null
              ? null
              : () => context.push(AppRoutes.channelFor(other.displayName))
        ),
        (
          conversation.isMuted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          conversation.isMuted ? 'Unmute' : 'Mute',
          () => _mute(context, conversation)
        ),
        (
          Icons.photo_library_outlined,
          'Media',
          () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SharedMediaPage(
                  attachments: sharedAttachments(state.messages))))
        ),
      ]),
      _MediaStrip(attachments: sharedAttachments(state.messages)),
      const SizedBox(height: 22),
      SettingsGroup([
        if (other != null)
          SettingsRow(
            title: 'Verify security code',
            icon: Icons.verified_user_outlined,
            subtitle: conversation.isEncrypted
                ? 'Messages are end-to-end encrypted'
                : 'Encryption starts with the next message',
            onTap: () => SafetyNumberSheet.show(context,
                userId: other.userId, name: other.displayName),
          ),
      ]),
      const SizedBox(height: 22),
      SettingsGroup([
        if (other != null)
          SettingsRow(
            title: 'Report $name',
            icon: Icons.flag_outlined,
            chevron: false,
            onTap: () => ReportSheet.show(
              context,
              targetType: ReportTargetType.profile,
              targetId: other.userId,
            ),
          ),
        SettingsRow(
          title: 'Delete conversation',
          icon: Icons.delete_outline_rounded,
          iconColor: context.palette.accent,
          titleColor: context.palette.accent,
          chevron: false,
          onTap: () async {
            final ok = await showConfirmSheet(
              context,
              title: 'Delete conversation?',
              body: 'It’s removed from your inbox. $name still has their copy.',
              actions: const [SheetAction('Delete', destructive: true)],
            );
            if (ok == 0) await cubit.deleteConversation();
          },
        ),
      ]),
    ]);
  }
}

class _GroupInfo extends StatelessWidget {
  const _GroupInfo({required this.state, required this.conversation});

  final ChatState state;
  final Conversation conversation;

  Future<void> _rename(BuildContext context) async {
    final cubit = context.read<ChatCubit>();
    final controller = TextEditingController(text: conversation.title ?? '');
    final saved = await showSoftSheet<bool>(context, (sheet) {
      final onSurface = Theme.of(sheet).colorScheme.onSurface;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rename group',
                  style: inter(19, weight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 16),
              SoftField(
                label: 'Group name',
                controller: controller,
                autofocus: true,
                help: 'Everyone in the group sees the new name.',
              ),
              PillButton(
                  label: 'Save',
                  onPressed: () => Navigator.of(sheet).pop(true)),
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(false),
                style: TextButton.styleFrom(
                    foregroundColor: onSurface,
                    textStyle: inter(16, weight: FontWeight.w500)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    });
    final title = controller.text.trim();
    controller.dispose();
    if (saved == true && title.isNotEmpty) await cubit.renameGroup(title);
  }

  Future<void> _member(BuildContext context, Participant p) async {
    final cubit = context.read<ChatCubit>();
    final canRemove =
        conversation.myRole.canManage && p.userId != state.myUserId;
    final pick = await showChoiceSheet(
      context,
      header: Row(
        children: [
          UserAvatar(name: p.displayName, radius: 26),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.displayName,
                  style: inter(17,
                      weight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
              if (p.profile != null)
                Text(p.profile!.role.displayName,
                    style: inter(13.5, color: context.palette.muted)),
            ],
          ),
        ],
      ),
      actions: [
        const SheetAction('View profile', icon: Icons.person_outline_rounded),
        const SheetAction('Message', icon: Icons.chat_bubble_outline_rounded),
        if (canRemove)
          const SheetAction('Remove from group',
              icon: Icons.remove_circle_outline_rounded, destructive: true),
      ],
    );
    if (!context.mounted || pick == null) return;
    switch (pick) {
      case 0:
        unawaited(context.push(AppRoutes.channelFor(p.displayName)));
      case 1:
        final id = await context.read<InboxCubit>().openDirect(p.userId);
        if (id != null && context.mounted) {
          unawaited(context.push(AppRoutes.chatFor(id)));
        }
      case 2:
        final ok = await showConfirmSheet(
          context,
          title: 'Remove ${p.displayName}?',
          body: 'They won’t see new messages in ${state.title}.',
          actions: const [SheetAction('Remove', destructive: true)],
        );
        if (ok == 0) await cubit.removeMember(p.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatCubit>();
    final palette = context.palette;
    final canManage = conversation.myRole.canManage;
    final members = [...conversation.participants]..sort((a, b) {
        int rank(Participant p) => p.userId == state.myUserId
            ? 3
            : p.role.canManage
                ? 0
                : 1;
        return rank(a).compareTo(rank(b));
      });
    final names = state.groupAvatarNames;

    return _Scaffold(
      action: canManage
          ? TextButton(
              onPressed: () => _rename(context),
              style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  textStyle: inter(16, weight: FontWeight.w500)),
              child: const Text('Edit'),
            )
          : null,
      children: [
        _Header(
          avatar: GroupAvatar(names: names, size: 76),
          title: state.title,
          subtitle: 'Group · ${members.length} members',
        ),
        _Actions(items: [
          (
            Icons.person_add_alt_rounded,
            'Add',
            canManage
                ? () => context.push(AppRoutes.addMembersFor(conversation.id))
                : null
          ),
          (
            conversation.isMuted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            conversation.isMuted ? 'Unmute' : 'Mute',
            () => _mute(context, conversation)
          ),
          (
            Icons.photo_library_outlined,
            'Media',
            () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SharedMediaPage(
                    attachments: sharedAttachments(state.messages))))
          ),
        ]),
        _MediaStrip(attachments: sharedAttachments(state.messages)),
        const SizedBox(height: 22),
        SectionLabel('${members.length} members'),
        _Members(
          members: members,
          myUserId: state.myUserId,
          onTap: (p) => _member(context, p),
        ),
        SettingsGroup([
          SettingsRow(
            title: 'Leave group',
            icon: Icons.logout_rounded,
            iconColor: palette.accent,
            titleColor: palette.accent,
            chevron: false,
            onTap: () async {
              final ok = await showConfirmSheet(
                context,
                title: 'Leave ${state.title}?',
                body: 'You won’t get new messages. Others can add you back.',
                actions: const [SheetAction('Leave group', destructive: true)],
              );
              if (ok == 0) await cubit.leave();
            },
          ),
        ]),
      ],
    );
  }
}

/// Every photo, video and file in the chat: Media as a grid, Files as a list.
class SharedMediaPage extends StatefulWidget {
  const SharedMediaPage({required this.attachments, super.key});

  final List<MessageAttachment> attachments;

  @override
  State<SharedMediaPage> createState() => _SharedMediaPageState();
}

class _SharedMediaPageState extends State<SharedMediaPage> {
  bool _files = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final media =
        widget.attachments.where((a) => a.isImage || a.isVideo).toList();
    final files =
        widget.attachments.where((a) => !a.isImage && !a.isVideo).toList();

    Widget tab(String label, bool value) {
      final on = _files == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _files = value),
          child: SizedBox(
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(label,
                    style: inter(15,
                        weight: on ? FontWeight.w600 : FontWeight.w400,
                        color: on ? onSurface : palette.muted)),
                const SizedBox(height: 10),
                Container(height: 2.5, width: on ? 56 : 0, color: onSurface),
              ],
            ),
          ),
        ),
      );
    }

    final empty = SoftMessage(
      icon: _files ? Icons.description_outlined : Icons.photo_library_outlined,
      title: _files ? 'No files yet' : 'No photos or videos yet',
      body: 'What you share in this chat shows up here.',
    );

    return Scaffold(
      appBar: softAppBar(context, 'Photos, videos and files'),
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border))),
            child: Row(children: [tab('Media', false), tab('Files', true)]),
          ),
          Expanded(
            child: _files
                ? (files.isEmpty
                    ? ListView(children: [const SizedBox(height: 80), empty])
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SettingsGroup([
                            for (final f in files)
                              SettingsRow(
                                title: f.name ?? 'File',
                                subtitle: formatBytes(f.size).isEmpty
                                    ? null
                                    : formatBytes(f.size),
                                icon: Icons.description_rounded,
                                iconColor: palette.verified,
                                chevron: false,
                                onTap: () => launchUrl(Uri.parse(f.url),
                                    mode: LaunchMode.externalApplication),
                              ),
                          ]),
                        ],
                      ))
                : (media.isEmpty
                    ? ListView(children: [const SizedBox(height: 80), empty])
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2),
                        itemCount: media.length,
                        itemBuilder: (context, i) =>
                            _MediaCell(attachment: media[i], all: media),
                      )),
          ),
        ],
      ),
    );
  }
}
