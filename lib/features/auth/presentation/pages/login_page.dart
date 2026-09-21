import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Trigger the Cubit action and await the boolean result
    final ok =
        await context.read<AuthCubit>().signIn(_email.text, _password.text);
    if (ok && mounted) context.go(AppRoutes.feed);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Sign in',
          subtitle: 'Access the intelligence feed.',
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No account?', style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                onPressed: () {
                  context.read<AuthCubit>().clearError();
                  context.push(AppRoutes.register);
                },
                child: const Text('Create one'),
              ),
            ],
          ),
          children: [
            if (state.failure != null)
              AuthErrorBanner(message: state.failure!.message),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Email'),
                    validator: (v) =>
                        (v ?? '').contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Enter your password' : null,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  context.read<AuthCubit>().clearError();
                  context.push(AppRoutes.forgotPassword);
                },
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SIGN IN'),
            ),
          ],
        );
      },
    );
  }
}
