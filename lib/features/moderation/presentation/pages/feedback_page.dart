import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/moderation_provider.dart';

/// Writes to `moderation.feedback`, whose `ratings` column is jsonb — the
/// per-area scores go in as a map.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const List<String> _areas = [
    'Feed quality',
    'Story accuracy',
    'Speed',
    'Design',
  ];

  final Map<String, int> _ratings = {};
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final provider = context.read<ModerationProvider>();
    final ok = await provider.submitFeedback(
      Map<String, dynamic>.from(_ratings),
      comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Thanks — feedback sent.' : provider.failure?.message ?? 'Failed.',
        ),
      ),
    );
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('FEEDBACK')),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            Text(
              'How is it working for you?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._areas.map((area) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.toUpperCase(),
                        style: AppTypography.mono(
                          size: 10,
                          color: palette.muted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: List.generate(5, (i) {
                          final value = i + 1;
                          final selected = (_ratings[area] ?? 0) >= value;
                          return IconButton(
                            onPressed: () =>
                                setState(() => _ratings[area] = value),
                            icon: Icon(
                              selected ? Icons.star_rounded : Icons.star_border_rounded,
                              color: selected ? palette.accent : palette.muted,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                )),
            TextField(
              controller: _comment,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Anything else? (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _ratings.isEmpty || _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SEND FEEDBACK'),
            ),
          ],
        ),
      ),
    );
  }
}
