import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';
import 'post_card.dart';

/// "Repost with a comment": your words on top, the original post under
/// them. Returns the comment, or null when cancelled.
class QuoteComposer extends StatefulWidget {
  const QuoteComposer({required this.post, this.username, super.key});

  final Post post;
  final String? username;

  static Future<String?> show(BuildContext context, Post post, {String? username}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuoteComposer(post: post, username: username),
    );
  }

  @override
  State<QuoteComposer> createState() => _QuoteComposerState();
}

class _QuoteComposerState extends State<QuoteComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _left => CreatePost.maxLength - _text.text.length;
  bool get _canPost => _text.text.trim().isNotEmpty && _left >= 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    TextStyle inter(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
        GoogleFonts.inter(
            fontSize: size, fontWeight: weight, color: color, letterSpacing: 0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text('Repost',
                        textAlign: TextAlign.center,
                        style: inter(17, weight: FontWeight.w600, color: onSurface)),
                  ),
                  FilledButton(
                    onPressed: _canPost
                        ? () => Navigator.of(context).pop(_text.text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(74, 36),
                      textStyle: inter(15, weight: FontWeight.w600),
                    ),
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border.withValues(alpha: 0.6)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(name: widget.username, radius: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.username != null)
                              Text(widget.username!,
                                  style: inter(15,
                                      weight: FontWeight.w600, color: onSurface)),
                            TextField(
                              controller: _text,
                              autofocus: true,
                              maxLines: null,
                              minLines: 2,
                              onChanged: (_) => setState(() {}),
                              style: inter(17, color: onSurface),
                              decoration: InputDecoration(
                                hintText: 'Add a comment',
                                hintStyle: inter(17, color: palette.muted),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            QuotedPostPreview(post: widget.post),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('$_left',
                                  style: inter(13,
                                      color: _left < 0 ? palette.accent : palette.muted)),
                            ),
                          ],
                        ),
                      ),
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
