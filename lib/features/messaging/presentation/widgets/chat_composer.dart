import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../feed/presentation/widgets/composer_emoji_panel.dart';
import '../../../feed/presentation/widgets/post_attachments.dart'
    show formatBytes;
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/messaging_usecases.dart';
import '../cubits/chat_cubit.dart';

/// The bottom of a chat: ➕ for the attach tray, the message box with an
/// emoji button, and send. Picked photos and files wait above the box until
/// sent, with the text as their caption. Reply and edit show a bar on top.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,
    required this.onSend,
    required this.onSendFiles,
    required this.isSending,
    this.replyTo,
    this.replySenderName,
    this.editing,
    this.onCancelReply,
    this.onCancelEdit,
    this.enabled = true,
    this.disabledHint,
    this.hint = 'Message',
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(List<PickedChatFile> files) onSendFiles;
  final bool isSending;
  final Message? replyTo;
  final String? replySenderName;
  final Message? editing;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCancelEdit;
  final bool enabled;
  final String? disabledHint;
  final String hint;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _focus = FocusNode();
  final List<PickedChatFile> _picked = [];
  bool _trayOpen = false;
  bool _emojiOpen = false;

  static const _maxFiles = 10;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggleTray() {
    FocusScope.of(context).unfocus();
    setState(() {
      _trayOpen = !_trayOpen;
      _emojiOpen = false;
    });
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _focus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _emojiOpen = true;
        _trayOpen = false;
      });
    }
  }

  void _insertEmoji(String emoji) {
    final c = widget.controller;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _add(Uint8List bytes, String type, String name) {
    if (_picked.length >= _maxFiles) return;
    if (bytes.length > UploadMessageAttachment.maxBytesFor(type)) {
      final mb = UploadMessageAttachment.maxBytesFor(type) ~/ (1024 * 1024);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('That file is over $mb MB.')));
      return;
    }
    setState(() => _picked.add(PickedChatFile(
          bytes: bytes,
          type: type,
          name: name,
          contentType: _mimeFor(name),
        )));
  }

  Future<void> _pick(int which) async {
    setState(() => _trayOpen = false);
    final left = _maxFiles - _picked.length;
    switch (which) {
      case 0:
        final files = await ImagePicker()
            .pickMultiImage(maxWidth: 2048, imageQuality: 85, limit: left);
        for (final f in files.take(left)) {
          if (!mounted) return;
          _add(await f.readAsBytes(), 'image', f.name);
        }
      case 1:
        final f = await ImagePicker().pickImage(
            source: ImageSource.camera, maxWidth: 2048, imageQuality: 85);
        if (f != null && mounted) _add(await f.readAsBytes(), 'image', f.name);
      case 2:
        final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (f != null && mounted) _add(await f.readAsBytes(), 'video', f.name);
      case 3:
        final f = await FilePicker.pickFile(type: FileType.any);
        if (f != null && mounted) {
          _add(await f.readAsBytes(), _typeForName(f.name), f.name);
        }
    }
  }

  void _send() {
    if (_picked.isNotEmpty) {
      widget.onSendFiles(List.of(_picked));
      setState(() => _picked.clear());
    } else {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final editing = widget.editing;
    final replyTo = widget.replyTo;

    Widget? banner;
    if (editing != null) {
      banner = _Banner(
        icon: Icons.edit_rounded,
        title: 'Edit message',
        body: editing.preview,
        onClose: widget.onCancelEdit,
      );
    } else if (replyTo != null) {
      banner = _Banner(
        bar: true,
        title: 'Replying to ${widget.replySenderName ?? 'message'}',
        body: replyTo.preview,
        onClose: widget.onCancelReply,
      );
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
                height: 1,
                thickness: 1,
                color: palette.border.withValues(alpha: 0.6)),
            if (banner != null) banner,
            if (_picked.isNotEmpty)
              _PickedStrip(
                files: _picked,
                onRemove: (f) => setState(() => _picked.remove(f)),
              ),
            if (_trayOpen) _Tray(onPick: _pick),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (editing == null) ...[
                    _Circle(
                      tooltip: _trayOpen ? 'Close' : 'Attach',
                      icon: _trayOpen ? Icons.close_rounded : Icons.add_rounded,
                      color: _trayOpen ? palette.accent : palette.surface2,
                      iconColor: _trayOpen ? Colors.white : onSurface,
                      onTap: widget.enabled ? _toggleTray : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _input(context, palette, onSurface)),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final can = widget.enabled &&
                          !widget.isSending &&
                          (value.text.trim().isNotEmpty || _picked.isNotEmpty);
                      return _Circle(
                        tooltip: editing != null ? 'Save' : 'Send',
                        icon: editing != null
                            ? Icons.check_rounded
                            : Icons.arrow_upward_rounded,
                        color: can ? palette.accent : palette.surface2,
                        iconColor: can ? Colors.white : palette.muted,
                        busy: widget.isSending,
                        onTap: can ? _send : null,
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_emojiOpen) ComposerEmojiPanel(onPick: _insertEmoji),
          ],
        ),
      ),
    );
  }

  Widget _input(BuildContext context, AppPalette palette, Color onSurface) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 5,
      maxLength: MessagingPolicy.maxBodyLength,
      textCapitalization: TextCapitalization.sentences,
      onTap: () {
        if (_emojiOpen || _trayOpen) {
          setState(() {
            _emojiOpen = false;
            _trayOpen = false;
          });
        }
      },
      style: inter(16, color: onSurface),
      decoration: InputDecoration(
        hintText: !widget.enabled
            ? widget.disabledHint ?? 'You can’t reply here'
            : _picked.isNotEmpty
                ? 'Add a caption'
                : widget.hint,
        hintStyle: inter(16, color: palette.muted),
        counterText: '',
        filled: true,
        fillColor: palette.surface2,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        disabledBorder: border,
        suffixIcon: IconButton(
          tooltip: _emojiOpen ? 'Keyboard' : 'Emoji',
          icon: Icon(
              _emojiOpen
                  ? Icons.keyboard_alt_outlined
                  : Icons.sentiment_satisfied_alt_rounded,
              color: _emojiOpen ? palette.accent : palette.muted),
          onPressed: widget.enabled ? _toggleEmoji : null,
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 42,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: iconColor))
                  : Icon(icon, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Photos, Camera, Videos, Files.
class _Tray extends StatelessWidget {
  const _Tray({required this.onPick});

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final items = [
      (Icons.photo_library_rounded, 'Photos', palette.accent),
      (Icons.photo_camera_rounded, 'Camera', onSurface),
      (Icons.videocam_rounded, 'Videos', palette.verified),
      (Icons.description_rounded, 'Files', palette.warn),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            Semantics(
              button: true,
              label: items[i].$2,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onPick(i),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                          color: palette.surface2,
                          borderRadius: BorderRadius.circular(20)),
                      child: Icon(items[i].$1, size: 28, color: items[i].$3),
                    ),
                    const SizedBox(height: 6),
                    Text(items[i].$2, style: inter(13, color: onSurface)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickedStrip extends StatelessWidget {
  const _PickedStrip({required this.files, required this.onRemove});

  final List<PickedChatFile> files;
  final ValueChanged<PickedChatFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = files[i];
          final tile = f.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(f.bytes,
                      width: 88, height: 88, fit: BoxFit.cover))
              : Container(
                  width: f.type == 'video' ? 88 : 156,
                  height: 88,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: palette.surface2,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          f.type == 'video'
                              ? Icons.videocam_rounded
                              : Icons.description_rounded,
                          color: f.type == 'video'
                              ? palette.verified
                              : palette.verified),
                      const Spacer(),
                      Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: inter(13,
                              weight: FontWeight.w500, color: onSurface)),
                      Text(formatBytes(f.bytes.length),
                          style: inter(12, color: palette.muted)),
                    ],
                  ),
                );
          return Stack(
            children: [
              tile,
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () => onRemove(f),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.body,
    this.icon,
    this.bar = false,
    this.onClose,
  });

  final IconData? icon;
  final bool bar;
  final String title;
  final String body;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          if (bar)
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(2)),
            )
          else
            Icon(icon, size: 22, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: inter(13,
                        weight: FontWeight.w600, color: palette.accent)),
                const SizedBox(height: 2),
                Text(body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: inter(14, color: palette.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            icon: Icon(Icons.close_rounded, color: palette.muted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

String _typeForName(String name) {
  final ext = name.split('.').last.toLowerCase();
  if (const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'}
      .contains(ext)) {
    return 'image';
  }
  if (const {'mp4', 'm4v', 'mov', 'webm'}.contains(ext)) return 'video';
  return 'file';
}

String? _mimeFor(String name) => switch (name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => null,
    };
