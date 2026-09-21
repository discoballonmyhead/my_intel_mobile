import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Check your inbox',
          subtitle: 'We sent a confirmation link to $email. '
              'Open it to activate your account.',
          children: [
            if (state.failure != null)
              AuthErrorBanner(message: state.failure!.message),
            OutlinedButton(
              onPressed: state.isLoading || email.isEmpty
                  ? null
                  : () async {
                      final ok = await context
                          .read<AuthCubit>()
                          .resendVerification(email);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Confirmation email resent.')),
                        );
                      }
                    },
              child: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('RESEND EMAIL'),
            ),
            const SizedBox(height: AppSpacing.md),
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
