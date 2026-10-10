import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../cubits/delete_account_cubit.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: softAppBar(context, 'Delete account'),
      body: BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
        builder: (context, state) {
          final cubit = context.read<DeleteAccountCubit>();
          return ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 40),
              children: [
                Icon(Icons.warning_amber_rounded, size: 44, color: palette.accent),
                const SizedBox(height: 16),
                Text('This can\u2019t be undone',
                    textAlign: TextAlign.center,
                    style: inter(22, weight: FontWeight.w600, color: onSurface)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'Your profile, posts, likes, reposts, follows and saved posts are '
                    'erased. Messages you sent show as \u201cdeleted\u201d. Reports you '
                    'filed stay with moderators, without your name.',
                    textAlign: TextAlign.center,
                    style: inter(15, color: palette.muted, height: 1.45),
                  ),
                ),
                const SizedBox(height: 28),
                SoftField(
                  label: 'Type ${AccountRpc.deleteConfirmation} to confirm',
                  controller: _confirm,
                  hint: AccountRpc.deleteConfirmation,
                  error: state.failure?.message,
                  onChanged: cubit.updateConfirmation,
                  capitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 6),
                PillButton(
                  label: 'Delete my account forever',
                  soft: !state.canSubmit,
                  loading: state.isSubmitting,
                  onPressed: state.canSubmit ? cubit.submit : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
