import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum AttachKind { photo, video, file, audio, poll }

/// The card that opens above the composer's attach button: one row per kind,
/// each with its own tinted icon.
class ComposerAttachMenu extends StatelessWidget {
  const ComposerAttachMenu({required this.onPick, super.key});

  final ValueChanged<AttachKind> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final rows = <(AttachKind, IconData, String, Color)>[
      (AttachKind.photo, Icons.image_outlined, 'Photos', palette.accent),
      (AttachKind.video, Icons.videocam_outlined, 'Videos', palette.accent2),
      (AttachKind.file, Icons.description_outlined, 'Files', palette.verified),
      (AttachKind.audio, Icons.mic_none_rounded, 'Audio', palette.warn),
      (AttachKind.poll, Icons.poll_outlined, 'Poll', onSurface),
    ];

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 210,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (kind, icon, label, color) in rows)
                InkWell(
                  onTap: () => onPick(kind),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 20, color: color),
                        ),
                        const SizedBox(width: 12),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
