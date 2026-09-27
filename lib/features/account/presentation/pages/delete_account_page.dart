import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubits/delete_account_cubit.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('DELETE ACCOUNT')),
      body: BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
        builder: (context, state) {
          final cubit = context.read<DeleteAccountCubit>();
          return ContentColumn(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 36, color: palette.accent2),
                const SizedBox(height: AppSpacing.lg),
                Text('This cannot be undone.',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Deleting your account permanently removes your profile, '
                  'posts, likes, reposts, follows and saved posts. Messages '
                  'you sent are replaced with a "deleted" placeholder for the '
                  'people you talked to. Reports you filed stay with the '
                  'moderation team, without your name.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'TYPE ${AccountRpc.deleteConfirmation} TO CONFIRM',
                  style: AppTypography.mono(
                      size: 10, color: palette.muted, letterSpacing: 1.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  enabled: !state.isSubmitting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: cubit.updateConfirmation,
                  decoration: InputDecoration(
                    hintText: AccountRpc.deleteConfirmation,
                    errorText: state.failure?.message,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: state.canSubmit ? cubit.submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent2,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('DELETE MY ACCOUNT FOREVER'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
