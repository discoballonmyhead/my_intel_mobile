import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Reset password',
          subtitle: _sent
              ? 'If that address has an account, a reset link is on its way.'
              : 'We will email you a link to set a new password.',
          children: [
            if (state.failure != null)
              AuthErrorBanner(message: state.failure!.message),
            if (!_sent) ...[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final ok = await context
                            .read<AuthCubit>()
                            .sendPasswordReset(_email.text);
                        if (ok && mounted) setState(() => _sent = true);
                      },
                child: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SEND RESET LINK'),
              ),
            ] else
              FilledButton(
                onPressed: () {
                  context.read<AuthCubit>().clearError();
                  context.go(AppRoutes.login);
                },
                child: const Text('BACK TO SIGN IN'),
              ),
          ],
        );
      },
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Set a new password',
          subtitle: 'Choose something you have not used before.',
          children: [
            if (state.failure != null)
              AuthErrorBanner(message: state.failure!.message),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'New password'),
                    validator: (v) =>
                        (v ?? '').length >= 8 ? null : 'At least 8 characters',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration:
                        const InputDecoration(hintText: 'Confirm password'),
                    validator: (v) =>
                        v == _password.text ? null : 'Passwords do not match',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final ok = await context
                          .read<AuthCubit>()
                          .updatePassword(_password.text);
                      if (ok && mounted) context.go(AppRoutes.feed);
                    },
              child: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('UPDATE PASSWORD'),
            ),
          ],
        );
      },
    );
  }
}
