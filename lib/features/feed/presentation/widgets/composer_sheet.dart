import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/usecases/create_post.dart';

/// Bottom-sheet composer. Sized against the keyboard inset so the send button
/// stays reachable one-handed on a phone.
class ComposerSheet extends StatefulWidget {
  const ComposerSheet({this.busy = false, super.key});

  final bool busy;

  static Future<CreatePostParams?> show(BuildContext context) {
    return showModalBottomSheet<CreatePostParams>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ComposerSheet(),
    );
  }

  @override
  State<ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<ComposerSheet> {
  final _controller = TextEditingController();
  final _region = TextEditingController();
  String? _tag;

  @override
  void dispose() {
    _controller.dispose();
    _region.dispose();
    super.dispose();
  }

  void _submit() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    Navigator.of(context).pop(CreatePostParams(
      body: body,
      tag: _tag,
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remaining = CreatePost.maxLength - _controller.text.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                maxLength: CreatePost.maxLength,
                onChanged: (_) => setState(() {}),
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(
                  hintText: 'Share an update…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('TAG', style: AppTypography.mono(size: 9, color: palette.muted)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: AppConstants.composerTags
                    .map((tag) => TagChip(
                          label: tag,
                          selected: _tag == tag,
                          onTap: () => setState(
                            () => _tag = _tag == tag ? null : tag,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _region,
                decoration: const InputDecoration(hintText: 'Region (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    '$remaining',
                    style: AppTypography.mono(
                      size: 10,
                      color: remaining < 0 ? palette.accent2 : palette.muted,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    child: const Text('POST'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
