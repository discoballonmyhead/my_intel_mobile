import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_widgets.dart';

/// Step 1 and 2 of recovery: ask for the email, then confirm the link went out.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthCubit>().sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  void _backToSignIn() {
    context.read<AuthCubit>().clearError();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (_sent) {
          return AuthScaffold(
            topBar: AuthStatusBar(
              label: 'LINK TRANSMITTED · 2/3',
              dotColor: palette.verified,
              onBack: () => setState(() => _sent = false),
            ),
            stage: RecoveryStage(
              icon: Icons.mark_email_read_outlined,
              caption: 'EMAIL SENT',
              tint: palette.verified,
              waves: true,
            ),
            form: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthHeading(
                  title: 'Check your inbox',
                  body: Text.rich(TextSpan(
                    text: 'We sent a reset link to ',
                    children: [
                      TextSpan(
                        text: _email.text.trim(),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(
                          text: '. Open it on this phone to choose a new password.'),
                    ],
                  )),
                ),
                const SizedBox(height: 14),
                const AuthTip(text: 'Not there? Check your spam folder.'),
                const SizedBox(height: 14),
                if (state.failure != null)
                  AuthErrorBanner(message: state.failure!.message),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _sent = false),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: const Text('Use a different email'),
                    ),
                    ResendButton(
                      onResend: () => context
                          .read<AuthCubit>()
                          .sendPasswordReset(_email.text),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AuthPrimaryButton(label: 'BACK TO SIGN IN', onPressed: _backToSignIn),
              ],
            ),
          );
        }

        return AuthScaffold(
          topBar: AuthStatusBar(
            label: 'SECURE RECOVERY · 1/3',
            onBack: _backToSignIn,
          ),
          stage: const RecoveryStage(
            icon: Icons.key_rounded,
            caption: 'RECOVER ACCESS',
          ),
          form: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeading(
                  title: 'Forgot your password?',
                  body: Text(
                      'Enter the email you signed up with and we’ll send you a link to reset it.'),
                ),
                const SizedBox(height: 18),
                if (state.failure != null)
                  AuthErrorBanner(message: state.failure!.message),
                AuthField(
                  controller: _email,
                  hint: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _send(),
                  validator: (v) => (v ?? '').trim().contains('@')
                      ? null
                      : 'Enter a valid email',
                ),
                const SizedBox(height: 14),
                AuthPrimaryButton(
                  label: 'SEND RESET LINK',
                  loading: state.isLoading,
                  onPressed: _send,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _backToSignIn,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Step 3: the app opened from the reset link; choose a new password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      _password.text.length >= 8 && _password.text == _confirm.text;

  Future<void> _update() async {
    final ok = await context.read<AuthCubit>().updatePassword(_password.text);
    if (ok && mounted) context.go(AppRoutes.feed);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          topBar: const AuthStatusBar(label: 'NEW CREDENTIALS · 3/3'),
          stage: const RecoveryStage(
            icon: Icons.lock_outline_rounded,
            caption: 'SECURE',
          ),
          form: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeading(
                  title: 'Set a new password',
                  body: Text('Choose something you haven’t used before.'),
                ),
                const SizedBox(height: 18),
                if (state.failure != null)
                  AuthErrorBanner(message: state.failure!.message),
                AuthField(
                  controller: _password,
                  hint: 'New password',
                  icon: Icons.lock_outline_rounded,
                  obscurable: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AuthField(
                  controller: _confirm,
                  hint: 'Confirm password',
                  icon: Icons.lock_outline_rounded,
                  obscurable: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_ready) _update();
                  },
                ),
                const SizedBox(height: 12),
                PasswordChecklist(
                    password: _password.text, confirm: _confirm.text),
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  label: 'UPDATE PASSWORD',
                  loading: state.isLoading,
                  onPressed: _ready ? _update : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
