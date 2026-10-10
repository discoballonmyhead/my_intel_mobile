import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_cubit.dart';
import '../../domain/entities/post_extras.dart';
import '../../domain/usecases/create_post.dart';
import 'composer_attach_menu.dart';
import 'composer_emoji_panel.dart';

/// Full-height "New post" sheet. Text on top, then up to four attachments
/// and an optional poll; one quiet row at the bottom with the attach and emoji
/// buttons, then region and News chips. News asks for confirmation first, as
/// on the web app, and cannot carry a poll.
class ComposerSheet extends StatefulWidget {
  const ComposerSheet({super.key});

  static Future<CreatePostParams?> show(BuildContext context) {
    return showModalBottomSheet<CreatePostParams>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ComposerSheet(),
    );
  }

  @override
  State<ComposerSheet> createState() => _ComposerSheetState();
}

const _audioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg'];

String? _mimeFor(AttachmentKind kind, String ext) => switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => kind == AttachmentKind.audio ? 'audio/webm' : 'video/webm',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      _ => null,
    };

String _extensionOf(String name, String fallback) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return fallback;
  final ext = name.substring(dot + 1).toLowerCase();
  return ext == 'jpeg' ? 'jpg' : ext;
}

/// A photo or video picked through Files is attached as one, so the feed
/// shows it instead of a file row.
AttachmentKind _kindForFile(String name) => switch (_extensionOf(name, '')) {
      'jpg' || 'png' || 'webp' || 'gif' || 'heic' || 'heif' =>
        AttachmentKind.image,
      'mp4' || 'm4v' || 'mov' => AttachmentKind.video,
      final ext when _audioExtensions.contains(ext) => AttachmentKind.audio,
      _ => AttachmentKind.file,
    };

class _ComposerSheetState extends State<ComposerSheet> {
  final _body = TextEditingController();
  final _focus = FocusNode();
  String? _region;
  bool _news = false;
  final List<PendingAttachment> _attachments = [];

  /// Option fields of the poll being written; null when there is no poll.
  List<TextEditingController>? _pollOptions;
  int _pollHours = 24;
  bool _attachOpen = false;
  bool _emojiOpen = false;
  String? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _disposePoll();
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _left => CreatePost.maxLength - _body.text.length;
  PollDraft? get _pollDraft {
    final fields = _pollOptions;
    if (fields == null) return null;
    return PollDraft(
        options: [for (final f in fields) f.text], durationHours: _pollHours);
  }

  int get _slotsLeft => CreatePost.maxAttachments - _attachments.length;

  bool get _canPost {
    final poll = _pollDraft;
    if (poll != null && (!poll.isValid || _news)) return false;
    return (_body.text.trim().isNotEmpty ||
            _attachments.isNotEmpty ||
            poll != null) &&
        _left >= 0;
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    if (_news && !await _confirmNews()) return;
    if (!mounted) return;
    Navigator.of(context).pop(CreatePostParams(
      body: _body.text.trim(),
      region: _region,
      postType: _news ? 'news' : 'general',
      attachments: List.of(_attachments),
      poll: _pollDraft,
    ));
  }

  void _toggleAttach() {
    HapticFeedback.selectionClick();
    setState(() {
      _attachOpen = !_attachOpen;
      if (_attachOpen) _emojiOpen = false;
    });
  }

  void _toggleEmoji() {
    HapticFeedback.selectionClick();
    final opening = !_emojiOpen;
    if (opening) {
      _focus.unfocus();
    } else {
      _focus.requestFocus();
    }
    setState(() {
      _emojiOpen = opening;
      _attachOpen = false;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _body.text;
    final sel = _body.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }

  Future<void> _onAttach(AttachKind kind) async {
    setState(() => _attachOpen = false);
    if (kind == AttachKind.poll) {
      _addPoll();
      return;
    }
    if (_slotsLeft <= 0) {
      _showNotice('A post can have up to ${CreatePost.maxAttachments} attachments.');
      return;
    }
    switch (kind) {
      case AttachKind.photo:
        await _pickPhotos();
      case AttachKind.video:
        await _pickVideo();
      case AttachKind.file:
        await _pickFile(AttachmentKind.file);
      case AttachKind.audio:
        await _pickFile(AttachmentKind.audio);
      case AttachKind.poll:
        break;
    }
  }

  Future<void> _pickPhotos() async {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      imageQuality: 85,
      limit: _slotsLeft,
    );
    for (final file in files.take(_slotsLeft)) {
      if (!mounted) return;
      final bytes = await file.readAsBytes();
      _addAttachment(AttachmentKind.image, bytes, file.name, 'jpg');
    }
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    if (await file.length() > AttachmentKind.video.maxBytes) {
      _tooLarge(AttachmentKind.video);
      return;
    }
    final bytes = await file.readAsBytes();
    _addAttachment(AttachmentKind.video, bytes, file.name, 'mp4');
  }

  Future<void> _pickFile(AttachmentKind kind) async {
    final audio = kind == AttachmentKind.audio;
    final file = await FilePicker.pickFile(
      type: audio ? FileType.custom : FileType.any,
      allowedExtensions: audio ? _audioExtensions : null,
    );
    if (file == null || !mounted) return;
    final picked = audio ? kind : _kindForFile(file.name);
    if ((await file.length() ?? 0) > picked.maxBytes) {
      _tooLarge(picked);
      return;
    }
    final bytes = await file.readAsBytes();
    _addAttachment(picked, bytes, file.name, audio ? 'm4a' : 'bin');
  }

  void _addAttachment(
      AttachmentKind kind, Uint8List bytes, String name, String fallbackExt) {
    if (!mounted || _slotsLeft <= 0) return;
    if (bytes.length > kind.maxBytes) {
      _tooLarge(kind);
      return;
    }
    final ext = _extensionOf(name, fallbackExt);
    setState(() => _attachments.add(PendingAttachment(
          kind: kind,
          bytes: bytes,
          extension: ext,
          contentType: _mimeFor(kind, ext),
          fileName: name,
        )));
  }

  void _tooLarge(AttachmentKind kind) {
    final mb = kind.maxBytes ~/ (1024 * 1024);
    _showNotice('That file is over the $mb MB limit for ${kind.name}s.');
  }

  void _addPoll() {
    if (_pollOptions != null) return;
    if (_news) {
      _showNotice('News posts cannot have a poll.');
      return;
    }
    setState(() {
      _pollOptions = [TextEditingController(), TextEditingController()];
      _pollHours = 24;
    });
  }

  void _removePoll() {
    final fields = _pollOptions;
    setState(() => _pollOptions = null);
    if (fields != null) _disposeAfterFrame(fields);
  }

  /// Option fields are still mounted during the setState that removes them,
  /// so their controllers are disposed once that frame is done.
  void _disposeAfterFrame(List<TextEditingController> controllers) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  void _disposePoll() {
    for (final c in _pollOptions ?? const <TextEditingController>[]) {
      c.dispose();
    }
    _pollOptions = null;
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _editRegion() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RegionDialog(initial: _region),
    );
    if (result == null || !mounted) return;
    final value = result.trim();
    setState(() => _region = value.isEmpty ? null : value);
  }

  Future<bool> _confirmNews() async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: palette.warn),
                  const SizedBox(width: 8),
                  Text('POST AS NEWS?',
                      style: AppTypography.mono(
                          size: 13,
                          weight: FontWeight.w800,
                          color: palette.warn,
                          letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to post this as News? If it turns out to be '
                'inappropriate or false, the penalty could be a temporary or '
                'permanent ban from further use of your account.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Post as news'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.muted,
                    textStyle: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final username =
        context.select<ProfileCubit, String?>((c) => c.state.profile?.username);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Stack(
          children: [
            Column(
              children: [
                // × · New post · Post
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 16, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 26),
                        color: onSurface,
                        tooltip: 'Close',
                      ),
                      Expanded(
                        child: Text('New post',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      FilledButton(
                        onPressed: _canPost ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              onSurface.withValues(alpha: 0.12),
                          disabledForegroundColor:
                              onSurface.withValues(alpha: 0.38),
                          minimumSize: const Size(74, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: const StadiumBorder(),
                          textStyle: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
                // Author + text + photo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(name: username, radius: 19),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (username != null)
                                Text(username,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              Expanded(
                                child: TextField(
                                  controller: _body,
                                  focusNode: _focus,
                                  autofocus: true,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      fontSize: 17, height: 1.5),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'What’s happening? Share an update…',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                              if (_attachments.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    height: 96,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _attachments.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (_, i) => _AttachmentThumb(
                                        attachment: _attachments[i],
                                        onRemove: () => setState(
                                            () => _attachments.removeAt(i)),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_pollOptions case final fields?)
                                Flexible(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PollEditor(
                                      fields: fields,
                                      hours: _pollHours,
                                      onChanged: () => setState(() {}),
                                      onAddOption: () => setState(() =>
                                          fields.add(TextEditingController())),
                                      onRemoveOption: (i) {
                                        final removed = fields.removeAt(i);
                                        setState(() {});
                                        _disposeAfterFrame([removed]);
                                      },
                                      onHours: (h) =>
                                          setState(() => _pollHours = h),
                                      onRemove: _removePoll,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Notice + character ring
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _notice == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          child: Text(_notice ?? '',
                              style: TextStyle(
                                  fontSize: 13, color: palette.muted)),
                        ),
                      ),
                      _CharRing(left: _left),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
                // attach · emoji | region · News
                SizedBox(
                  height: 60,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        _RoundIcon(
                          icon: Icons.add_photo_alternate_outlined,
                          color: palette.accent,
                          active: _attachOpen ||
                              _attachments.isNotEmpty ||
                              _pollOptions != null,
                          tooltip: 'Attach',
                          onTap: _toggleAttach,
                        ),
                        const SizedBox(width: 2),
                        _RoundIcon(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          color: _emojiOpen ? palette.accent : palette.muted,
                          active: _emojiOpen,
                          tooltip: 'Emoji',
                          onTap: _toggleEmoji,
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: palette.border,
                        ),
                        _Chip(
                          icon: Icons.place_outlined,
                          label: _region ?? 'Add region',
                          placeholder: _region == null,
                          onTap: _editRegion,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: Icons.newspaper_rounded,
                          label: 'News',
                          active: _news,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (!_news && _pollOptions != null) {
                              _showNotice('News posts cannot have a poll.');
                              return;
                            }
                            setState(() => _news = !_news);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _news
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Marked as a news report. False news can lead to a ban.',
                              style: TextStyle(
                                  fontSize: 12, color: palette.muted),
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (_emojiOpen) ComposerEmojiPanel(onPick: _insertEmoji),
              ],
            ),
            if (_attachOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _attachOpen = false),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 60 + (_news ? 28 : 0) + 8,
                child: ComposerAttachMenu(onPick: _onAttach),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small dialog to type a region. It owns its controller, so the controller
/// lives until the dialog has finished closing.
class _RegionDialog extends StatefulWidget {
  const _RegionDialog({this.initial});

  final String? initial;

  @override
  State<_RegionDialog> createState() => _RegionDialogState();
}

class _RegionDialogState extends State<_RegionDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Region'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Mumbai, India'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// 36pt round icon button; a light tint marks it as on.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? palette.accent.withValues(alpha: 0.10) : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Outlined chip for region and News; News turns light red when on.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.placeholder = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fg = active
        ? palette.accent
        : placeholder
            ? palette.muted
            : onSurface;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? palette.accent.withValues(alpha: 0.10) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
              color: active
                  ? palette.accent.withValues(alpha: 0.45)
                  : palette.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? palette.accent : palette.muted),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.onRemove});

  final PendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color) = switch (attachment.kind) {
      AttachmentKind.video => (Icons.videocam_outlined, palette.accent2),
      AttachmentKind.audio => (Icons.mic_none_rounded, palette.warn),
      _ => (Icons.description_outlined, palette.verified),
    };
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: attachment.kind == AttachmentKind.image
                  ? Image.memory(attachment.bytes, fit: BoxFit.cover)
                  : Container(
                      color: palette.surface2,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: color, size: 26),
                          const SizedBox(height: 6),
                          Text(attachment.fileName ?? attachment.kind.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: palette.muted)),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              label: 'Remove attachment',
              button: true,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two to four option fields, a length picker and a remove button.
class _PollEditor extends StatelessWidget {
  const _PollEditor({
    required this.fields,
    required this.hours,
    required this.onChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onHours,
    required this.onRemove,
  });

  final List<TextEditingController> fields;
  final int hours;
  final VoidCallback onChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<int> onHours;
  final VoidCallback onRemove;

  static String _label(int h) => h < 24 ? '${h}h' : '${h ~/ 24}d';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 18, color: palette.muted),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Poll',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'Remove poll',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: palette.muted,
              ),
            ],
          ),
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fields[i],
                      maxLength: PollDraft.maxLabelLength,
                      onChanged: (_) => onChanged(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Option ${i + 1}',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  if (fields.length > PollDraft.minOptions)
                    IconButton(
                      tooltip: 'Remove option',
                      onPressed: () => onRemoveOption(i),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      color: palette.muted,
                    ),
                ],
              ),
            ),
          Row(
            children: [
              if (fields.length < PollDraft.maxOptions)
                TextButton.icon(
                  onPressed: onAddOption,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add option'),
                ),
              const Spacer(),
              Text('Ends in', style: TextStyle(fontSize: 13, color: palette.muted)),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: hours,
                underline: const SizedBox.shrink(),
                items: [
                  for (final h in PollDraft.durationChoices)
                    DropdownMenuItem(value: h, child: Text(_label(h))),
                ],
                onChanged: (h) => h == null ? null : onHours(h),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fills as the post approaches the length limit; shows the count near it.
class _CharRing extends StatelessWidget {
  const _CharRing({required this.left});

  /// Characters left when the count appears and the ring turns amber.
  static const int warnAt = 50;

  final int left;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const max = CreatePost.maxLength;
    final used = (max - left).clamp(0, max);
    final color = left < 0
        ? palette.accent2
        : left <= _CharRing.warnAt
            ? palette.warn
            : palette.accent;

    return Semantics(
      label: '$left characters left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (left <= _CharRing.warnAt) ...[
            Text('$left',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 6),
          ],
          SizedBox.square(
            dimension: 22,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: used / max,
                color: color,
                track: palette.surface2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 1.5;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = track;
    canvas.drawCircle(rect.center, radius, base);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0, 1),
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
