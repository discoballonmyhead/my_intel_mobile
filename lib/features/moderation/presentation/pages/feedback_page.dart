import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/moderation_provider.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

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

    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: softAppBar(context, 'Send feedback'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
              child: Text('How is MINT working for you?',
                  style: inter(18, weight: FontWeight.w600, color: onSurface)),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _areas.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_areas[i],
                                style: inter(16, color: onSurface)),
                          ),
                          for (var v = 1; v <= 5; v++)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: '$v of 5',
                              onPressed: () => setState(() => _ratings[_areas[i]] = v),
                              icon: Icon(
                                (_ratings[_areas[i]] ?? 0) >= v
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: (_ratings[_areas[i]] ?? 0) >= v
                                    ? palette.accent
                                    : palette.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (i < _areas.length - 1)
                      Divider(height: 1, indent: 16, endIndent: 16, color: palette.border),
                  ],
                ],
              ),
            ),
            SoftField(
              label: 'Anything else? (optional)',
              controller: _comment,
              hint: 'Tell us what to improve',
              maxLines: 4,
            ),
            const SizedBox(height: 4),
            PillButton(
              label: 'Send feedback',
              loading: _sending,
              onPressed: _ratings.isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
