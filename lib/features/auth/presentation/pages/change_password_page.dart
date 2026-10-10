import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../domain/usecases/change_password.dart';
import '../cubits/change_password_cubit.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<ChangePasswordCubit>().submit(
          currentPassword: _current.text,
          newPassword: _new.text,
          confirmPassword: _confirm.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listenWhen: (a, b) =>
          a.isChanged != b.isChanged || a.resetEmailSent != b.resetEmailSent,
      listener: (context, state) {
        if (state.isChanged) {
          AppDialogs.snack(context, 'Password updated.');
          context.pop();
        } else if (state.resetEmailSent) {
          AppDialogs.snack(context, 'Reset link sent — check your email.');
        }
      },
      builder: (context, state) {
        final cubit = context.read<ChangePasswordCubit>();
        final busy = state.isSubmitting;

        InputDecoration decoration(String label, {String? helper}) =>
            InputDecoration(
              labelText: label,
              helperText: helper,
              suffixIcon: IconButton(
                tooltip: _showPasswords ? 'Hide' : 'Show',
                icon: Icon(_showPasswords
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _showPasswords = !_showPasswords),
              ),
            );

        return Scaffold(
          appBar: AppBar(title: const Text('CHANGE PASSWORD')),
          body: ContentColumn(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                children: [
                  TextFormField(
                    controller: _current,
                    enabled: !busy,
                    obscureText: !_showPasswords,
                    autofillHints: const [AutofillHints.password],
                    decoration: decoration('Current password'),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _new,
                    enabled: !busy,
                    obscureText: !_showPasswords,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: decoration('New password',
                        helper:
                            'At least ${ChangePassword.minLength} characters, '
                            'with a letter and a number'),
                    validator: (v) {
                      final problem = ChangePassword.validateNew(v ?? '');
                      if (problem != null) return problem;
                      if (v == _current.text) {
                        return 'Must differ from your current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _confirm,
                    enabled: !busy,
                    obscureText: !_showPasswords,
                    decoration: decoration('Confirm new password'),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v != _new.text ? 'The passwords do not match.' : null,
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.failure!.message,
                      style: TextStyle(color: palette.accent2),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('UPDATE PASSWORD'),
                  ),
                  if (cubit.email != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: state.isSendingReset || state.resetEmailSent
                          ? null
                          : cubit.sendResetEmail,
                      child: Text(state.resetEmailSent
                          ? 'Reset link sent to ${cubit.email}'
                          : 'Forgot your current password? Email me a reset link'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
