import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'We sent a confirmation link to $email. '
          'Open it to activate your account.',
      children: [
        if (auth.failure != null) AuthErrorBanner(message: auth.failure!.message),
        OutlinedButton(
          onPressed: auth.busy || email.isEmpty
              ? null
              : () async {
                  final ok = await auth.resendVerification(email);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Confirmation email resent.')),
                    );
                  }
                },
          child: const Text('RESEND EMAIL'),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('BACK TO SIGN IN'),
        ),
      ],
    );
  }
}
