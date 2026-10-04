import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_cubit.dart';
import '../../domain/usecases/create_post.dart';

/// Full-height "New post" sheet: text, General / News switch, optional region
/// and a character ring. News asks for confirmation first, as on the web app.
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

class _ComposerSheetState extends State<ComposerSheet> {
  final _body = TextEditingController();
  final _region = TextEditingController();
  bool _news = false;

  @override
  void dispose() {
    _body.dispose();
    _region.dispose();
    super.dispose();
  }

  int get _left => CreatePost.maxLength - _body.text.length;
  bool get _canPost => _body.text.trim().isNotEmpty && _left >= 0;

  Future<void> _submit() async {
    if (!_canPost) return;
    if (_news && !await _confirmNews()) return;
    if (!mounted) return;
    final region = _region.text.trim();
    Navigator.of(context).pop(CreatePostParams(
      body: _body.text.trim(),
      region: region.isEmpty ? null : region,
      postType: _news ? 'news' : 'general',
    ));
  }

  Future<bool> _confirmNews() async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: palette.warn),
            const SizedBox(width: 8),
            Text('POST AS NEWS?',
                style: AppTypography.mono(
                    size: 13, weight: FontWeight.w800, color: palette.warn,
                    letterSpacing: 1.5)),
          ],
        ),
        content: const Text(
          'Are you sure you want to post this as News? If it turns out to be '
          'inappropriate or false, the penalty could be a temporary or '
          'permanent ban from further use of your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: palette.verified),
            child: const Text('Post as news'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final username =
        context.select<ProfileCubit, String?>((c) => c.state.profile?.username);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            // Cancel · New post · Post
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                  ),
                  Expanded(
                    child: Text('New post',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  FilledButton(
                    onPressed: _canPost ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      minimumSize: const Size(72, 36),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
            // Author + text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
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
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          Expanded(
                            child: TextField(
                              controller: _body,
                              autofocus: true,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 17, height: 1.5),
                              decoration: const InputDecoration(
                                hintText: 'What’s happening? Share an update…',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
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
            // Post as · region · ring
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.surface2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('POST AS',
                      style: AppTypography.mono(
                          size: 9,
                          weight: FontWeight.w700,
                          color: palette.muted,
                          letterSpacing: 1.8)),
                  const SizedBox(height: 8),
                  _PostTypeSwitch(
                    news: _news,
                    onChanged: (v) => setState(() => _news = v),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _news
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'News: ',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(
                                      text: 'marked as a news report in the feed.'),
                                ],
                              ),
                              style: TextStyle(
                                  fontSize: 12, height: 1.4, color: palette.verified),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _region,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Region (optional)',
                            prefixIcon: Icon(Icons.place_outlined,
                                size: 18, color: palette.muted),
                            filled: true,
                            fillColor: palette.surface2.withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: palette.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CharRing(left: _left),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GENERAL | NEWS pill; the thumb slides and turns green on News.
class _PostTypeSwitch extends StatelessWidget {
  const _PostTypeSwitch({required this.news, required this.onChanged});

  final bool news;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget option(bool value, IconData icon, String label) {
      final selected = news == value;
      final color = selected ? Theme.of(context).colorScheme.surface : palette.muted;
      return Expanded(
        child: Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: selected
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTypography.mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: color,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: news ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                decoration: BoxDecoration(
                  color: news ? palette.verified : onSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Row(
            children: [
              option(false, Icons.chat_bubble_outline_rounded, 'GENERAL'),
              option(true, Icons.newspaper_rounded, 'NEWS'),
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
                style: AppTypography.mono(
                    size: 11, weight: FontWeight.w700, color: color)),
            const SizedBox(width: 6),
          ],
          SizedBox.square(
            dimension: 26,
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
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 10);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    canvas.drawCircle(rect.center, 10, base);
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
