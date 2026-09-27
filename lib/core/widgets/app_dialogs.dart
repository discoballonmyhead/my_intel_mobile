import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared dialogs for destructive and reason-required actions, so every
/// moderation / admin / delete flow asks the same way.
class AppDialogs {
  const AppDialogs._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'CONFIRM',
    bool destructive = false,
  }) async {
    final palette = context.palette;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: palette.accent2)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Returns the trimmed text, or null if cancelled. With [isRequired] the
  /// confirm button stays disabled until something is typed.
  static Future<String?> reason(
    BuildContext context, {
    required String title,
    String hint = 'Reason',
    String confirmLabel = 'CONFIRM',
    String? initialValue,
    bool isRequired = true,
    bool destructive = false,
    int maxLength = 500,
    int maxLines = 4,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
        isRequired: isRequired,
        destructive: destructive,
        maxLength: maxLength,
        maxLines: maxLines,
      ),
    );
  }

  static void snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.isRequired,
    required this.destructive,
    required this.maxLength,
    required this.maxLines,
    this.initialValue,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String? initialValue;
  final bool isRequired;
  final bool destructive;
  final int maxLength;
  final int maxLines;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !widget.isRequired || _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          minLines: 1,
          maxLines: widget.maxLines,
          decoration: InputDecoration(hintText: widget.hint),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: palette.accent2)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
