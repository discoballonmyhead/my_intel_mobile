import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_cubit.dart';
import '../../domain/usecases/create_post.dart';
import 'composer_attach_menu.dart';
import 'composer_emoji_panel.dart';

/// Full-height "New post" sheet. Text on top; one quiet row at the bottom with
/// the attach and emoji buttons, then region and News chips. News asks for
/// confirmation first, as on the web app.
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

class _PickedPhoto {
  const _PickedPhoto(this.bytes, this.extension, this.mimeType);
  final Uint8List bytes;
  final String extension;
  final String mimeType;
}

class _ComposerSheetState extends State<ComposerSheet> {
  final _body = TextEditingController();
  final _focus = FocusNode();
  String? _region;
  bool _news = false;
  _PickedPhoto? _photo;
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
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _left => CreatePost.maxLength - _body.text.length;
  bool get _canPost =>
      (_body.text.trim().isNotEmpty || _photo != null) && _left >= 0;

  Future<void> _submit() async {
    if (!_canPost) return;
    if (_news && !await _confirmNews()) return;
    if (!mounted) return;
    final photo = _photo;
    Navigator.of(context).pop(CreatePostParams(
      body: _body.text.trim(),
      region: _region,
      postType: _news ? 'news' : 'general',
      mediaBytes: photo?.bytes,
      mediaExtension: photo?.extension,
      mediaContentType: photo?.mimeType,
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
    switch (kind) {
      case AttachKind.photo:
        await _pickPhoto();
      case AttachKind.video:
        _showNotice('Videos are coming soon.');
      case AttachKind.file:
        _showNotice('Files are coming soon.');
      case AttachKind.audio:
        _showNotice('Audio is coming soon.');
      case AttachKind.poll:
        _showNotice('Polls are coming soon.');
    }
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
    if (!mounted) return;
    setState(() => _photo = _PickedPhoto(bytes, ext == 'jpeg' ? 'jpg' : ext, mime));
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _editRegion() async {
    final controller = TextEditingController(text: _region ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Region'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Mumbai, India'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          if (_region != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
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
                              if (_photo != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PhotoThumb(
                                    bytes: _photo!.bytes,
                                    onRemove: () =>
                                        setState(() => _photo = null),
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
                          active: _attachOpen || _photo != null,
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

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 124,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Semantics(
              label: 'Remove photo',
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

/// Fills as the post approaches the length limit; shows the count near it.
class _CharRing extends StatelessWidget {
  const _CharRing({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const max = CreatePost.maxLength;
    final used = (max - left).clamp(0, max);
    final color = left < 0
        ? palette.accent2
        : left <= 200
            ? palette.warn
            : palette.accent;

    return Semantics(
      label: '$left characters left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (left <= 200) ...[
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
