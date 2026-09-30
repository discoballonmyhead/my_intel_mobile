import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_widgets.dart';

/// Shown after Create account when Supabase wants the email confirmed.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    void backToSignIn() {
      context.read<AuthCubit>().clearError();
      context.go(AppRoutes.login);
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          topBar: AuthStatusBar(
            label: 'CONFIRM YOUR EMAIL',
            dotColor: palette.verified,
            onBack: backToSignIn,
          ),
          stage: RecoveryStage(
            icon: Icons.mark_email_unread_outlined,
            caption: 'ALMOST THERE',
            tint: palette.verified,
            waves: true,
          ),
          form: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeading(
                title: 'Check your inbox',
                body: Text.rich(TextSpan(
                  text: 'We sent a confirmation link to ',
                  children: [
                    TextSpan(
                      text: email.isEmpty ? 'your email' : email,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '. Open it to activate your account.'),
                  ],
                )),
              ),
              const SizedBox(height: 14),
              const AuthTip(text: 'Not there? Check your spam folder.'),
              const SizedBox(height: 14),
              if (state.failure != null)
                AuthErrorBanner(message: state.failure!.message),
              if (email.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: ResendButton(
                    onResend: () =>
                        context.read<AuthCubit>().resendVerification(email),
                  ),
                ),
              const SizedBox(height: 6),
              AuthPrimaryButton(label: 'BACK TO SIGN IN', onPressed: backToSignIn),
            ],
          ),
        );
      },
    );
  }
}
