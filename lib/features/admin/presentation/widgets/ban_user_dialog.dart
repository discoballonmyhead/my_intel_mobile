import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// What the moderator chose in [BanUserDialog].
class BanRequest {
  const BanRequest({
    required this.reason,
    this.duration,
    this.hideContent = false,
  });

  final String reason;

  /// Null = permanent ban.
  final Duration? duration;
  final bool hideContent;
}

/// Suspension / ban picker. Moderators only see options up to 7 days, which
/// is the same limit `admin_ban_user` enforces server-side.
class BanUserDialog extends StatefulWidget {
  const BanUserDialog._({required this.username, required this.allowPermanent});

  /// Display text for the title, e.g. "@alice" or "this user".
  final String username;
  final bool allowPermanent;

  static Future<BanRequest?> show(
    BuildContext context, {
    required String username,
    required bool allowPermanent,
  }) {
    return showDialog<BanRequest>(
      context: context,
      builder: (_) =>
          BanUserDialog._(username: username, allowPermanent: allowPermanent),
    );
  }

  @override
  State<BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<BanUserDialog> {
  static const Map<String, Duration?> _moderatorOptions = {
    '24 hours': Duration(hours: 24),
    '3 days': Duration(days: 3),
    '7 days': Duration(days: 7),
  };

  static const Map<String, Duration?> _adminOptions = {
    '24 hours': Duration(hours: 24),
    '3 days': Duration(days: 3),
    '7 days': Duration(days: 7),
    '30 days': Duration(days: 30),
    '90 days': Duration(days: 90),
    'Permanent': null,
  };

  final _reason = TextEditingController();
  late String _choice = '24 hours';
  bool _hideContent = false;

  Map<String, Duration?> get _options =>
      widget.allowPermanent ? _adminOptions : _moderatorOptions;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final permanent = _options[_choice] == null;

    return AlertDialog(
      title: Text(permanent
          ? 'Ban ${widget.username}'
          : 'Suspend ${widget.username}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DURATION',
                  style: AppTypography.mono(
                      size: 10, color: palette.muted, letterSpacing: 1.5)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _options.keys
                    .map((label) => ChoiceChip(
                          label: Text(label),
                          selected: _choice == label,
                          onSelected: (_) => setState(() => _choice = label),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _reason,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Reason (shown to the user)',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hideContent,
                onChanged: (v) => setState(() => _hideContent = v ?? false),
                title: const Text('Hide their posts'),
                subtitle: const Text('Moves all their posts to review'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(BanRequest(
                    reason: _reason.text.trim(),
                    duration: _options[_choice],
                    hideContent: _hideContent,
                  )),
          style: FilledButton.styleFrom(backgroundColor: palette.accent2),
          child: Text(permanent ? 'BAN' : 'SUSPEND'),
        ),
      ],
    );
  }
}
