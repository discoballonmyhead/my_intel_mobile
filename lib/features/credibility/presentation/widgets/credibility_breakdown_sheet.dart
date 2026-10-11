import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/credibility_report.dart';

/// How a credibility score was reached. Opened from the CRED stat / bar.
class CredibilityBreakdownSheet extends StatelessWidget {
  const CredibilityBreakdownSheet._({required this.report, this.username});

  final CredibilityReport report;
  final String? username;

  static Future<void> show(
    BuildContext context,
    CredibilityReport report, {
    String? username,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          CredibilityBreakdownSheet._(report: report, username: username),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final r = report;

    String signed(int v) => v > 0 ? '+$v' : '$v';

    final postRows = <(String, String)>[
      ('News posts (last 6 months)', '${r.totalPosts}'),
      ('Cited in a story', '${r.totalCited}'),
      ('Corroborated by other analysts', '${r.totalPeerCorr}'),
      ('Verified / confirmed reactions', '${r.positiveReactions}'),
      ('Disputed reactions', '${r.negativeReactions}'),
      ('Claims verified', '${r.verifiedClaims}'),
      ('Claims found false', '${r.falseClaims}'),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
        children: [
          Text(
            username == null ? 'Credibility' : 'Credibility · @$username',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.score}', style: theme.textTheme.headlineMedium),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('/ 100',
                    style: AppTypography.mono(size: 10, color: palette.muted)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(
            label: r.isBaseline
                ? 'New analyst baseline'
                : 'Average post score',
            value: '${r.baseScore}',
            strong: true,
          ),
          _Row(
            label: 'Accurate notes (${r.accurateNotes}/${r.totalRatedNotes})',
            value: signed(r.noteBoost),
          ),
          _Row(
            label: 'Consistency (${r.activeDays} active days / 30)',
            value: signed(r.consistencyBoost),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('SIGNALS',
              style: AppTypography.mono(
                  size: 10, color: palette.muted, letterSpacing: 1.5)),
          const SizedBox(height: AppSpacing.xs),
          for (final (label, value) in postRows) _Row(label: label, value: value),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Each news post starts at 50: +20 if cited in a story, +10 if '
            'posted 30+ min before that story, +15 if two other analysts '
            'reported the same tag or region within 24h, up to ±15 from '
            'reactions, and +15 / −30 / +5 for a verified / false / reversed '
            'claim.',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
