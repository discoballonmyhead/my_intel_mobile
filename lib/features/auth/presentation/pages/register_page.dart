import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.public;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      email: _email.text,
      password: _password.text,
      username: _username.text,
      role: _role,
    );
    if (!ok || !mounted) return;

    if (auth.needsEmailConfirmation) {
      context.go('${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}');
    } else {
      context.go(AppRoutes.feed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Analyst access is granted separately, after you apply.',
      children: [
        if (auth.failure != null) AuthErrorBanner(message: auth.failure!.message),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Username'),
                validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(v ?? '')
                    ? null
                    : '3-20 characters, letters, numbers or underscore',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Email'),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'Enter a valid email',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Password'),
                validator: (v) =>
                    (v ?? '').length >= 8 ? null : 'At least 8 characters',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(value: UserRole.public, label: Text('Reader')),
            ButtonSegment(value: UserRole.reporter, label: Text('Reporter')),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: auth.busy ? null : _submit,
          child: auth.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CREATE ACCOUNT'),
        ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already registered?',
              style: Theme.of(context).textTheme.bodySmall),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}
