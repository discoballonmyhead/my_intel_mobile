import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/community_note.dart';
import '../providers/moderation_provider.dart';

/// Open claims awaiting an admin decision. The route guard already checks the
/// role, and RLS enforces it again server-side.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ModerationProvider>().loadOpenClaims();
    });
  }

  Future<void> _resolve(Claim claim, String status) async {
    final provider = context.read<ModerationProvider>();
    final ok = await provider.resolveClaim(claim.id, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Claim marked $status. Credibility recalculated.'
              : provider.failure?.message ?? 'Could not resolve claim.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModerationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN')),
      body: RefreshIndicator(
        onRefresh: provider.loadOpenClaims,
        child: provider.loading
            ? const AppLoader(label: 'Loading claims')
            : provider.openClaims.isEmpty
                ? const AppEmptyView(
                    message: 'No open claims',
                    icon: Icons.gavel_outlined,
                  )
                : ContentColumn(
                    padded: false,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: provider.openClaims.length,
                      itemBuilder: (context, index) => _ClaimTile(
                        claim: provider.openClaims[index],
                        onResolve: (status) =>
                            _resolve(provider.openClaims[index], status),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.claim, required this.onResolve});

  final Claim claim;
  final ValueChanged<String> onResolve;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CLAIM #${claim.id}',
                style: AppTypography.mono(size: 10, color: palette.warn),
              ),
              const Spacer(),
              if (claim.createdAt != null)
                Text(
                  claim.createdAt!.timeAgo,
                  style: AppTypography.mono(size: 9, color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Raised against post #${claim.postId}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: () => onResolve('verified'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  foregroundColor: palette.verified,
                ),
                child: const Text('VERIFIED'),
              ),
              OutlinedButton(
                onPressed: () => onResolve('false'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  foregroundColor: palette.accent2,
                ),
                child: const Text('FALSE'),
              ),
              OutlinedButton(
                onPressed: () => onResolve('reversed'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                child: const Text('REVERSED'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
