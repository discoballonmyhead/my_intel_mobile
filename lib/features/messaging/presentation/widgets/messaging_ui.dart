import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/domain/entities/post_extras.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/message.dart';

/// Shared pieces for the Messages screens: group avatars, the soft bottom
/// sheets used for confirmations and choices, and small helpers. Text styles
/// come from the Profile UI (`inter`) so both tabs read the same.

/// Two overlapping initials for a group; the second sits on a ring of the
/// page background.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({required this.names, this.size = 52, super.key});

  final List<String> names;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = size * 0.62;
    final first = names.isNotEmpty ? names.first : 'G';
    final second = names.length > 1 ? names[1] : first;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          UserAvatar(name: first, radius: d / 2),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(name: second, radius: d / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in a [showChoiceSheet] or [showConfirmSheet].
class SheetAction {
  const SheetAction(this.label, {this.icon, this.destructive = false});

  final String label;
  final IconData? icon;
  final bool destructive;
}

/// Title, a short explanation, one or more pill buttons and Cancel. Returns
/// the index of the button tapped, or null when cancelled.
Future<int?> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required List<SheetAction> actions,
}) {
  return showSoftSheet<int>(context, (sheet) {
    final palette = sheet.palette;
    final onSurface = Theme.of(sheet).colorScheme.onSurface;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: inter(19, weight: FontWeight.w600, color: onSurface)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(body,
                  textAlign: TextAlign.center,
                  style: inter(15, color: palette.muted, height: 1.4)),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < actions.length; i++) ...[
              PillButton(
                label: actions[i].label,
                soft: !actions[i].destructive,
                onPressed: () => Navigator.of(sheet).pop(i),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(),
              style: TextButton.styleFrom(
                foregroundColor: onSurface,
                textStyle: inter(16, weight: FontWeight.w500),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  });
}

/// A list of icon + label rows in a sheet, with an optional header.
Future<int?> showChoiceSheet(
  BuildContext context, {
  required List<SheetAction> actions,
  Widget? header,
}) {
  return showSoftSheet<int>(context, (sheet) {
    final palette = sheet.palette;
    final onSurface = Theme.of(sheet).colorScheme.onSurface;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: header,
            ),
          for (var i = 0; i < actions.length; i++)
            InkWell(
              onTap: () => Navigator.of(sheet).pop(i),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                child: Row(
                  children: [
                    if (actions[i].icon != null) ...[
                      Icon(actions[i].icon,
                          size: 23,
                          color: actions[i].destructive
                              ? palette.accent
                              : onSurface),
                      const SizedBox(width: 18),
                    ],
                    Text(actions[i].label,
                        style: inter(16,
                            color: actions[i].destructive
                                ? palette.accent
                                : onSurface)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  });
}

/// Chat attachments drawn with the Feed's attachment widgets (photo grid,
/// video preview, file card), which already know how to open full screen.
List<PostAttachment> asPostAttachments(List<MessageAttachment> attachments) => [
      for (var i = 0; i < attachments.length; i++)
        PostAttachment(
          id: i,
          position: i,
          kind: attachments[i].isImage
              ? AttachmentKind.image
              : attachments[i].isVideo
                  ? AttachmentKind.video
                  : AttachmentKind.file,
          url: attachments[i].url,
          fileName: attachments[i].name,
          sizeBytes: attachments[i].size,
        ),
    ];
