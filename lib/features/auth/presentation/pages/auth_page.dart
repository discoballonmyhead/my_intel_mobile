import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_cubit.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/falling_reports.dart';

/// Sign in and Create account on one screen, switched by the pill at the top
/// of the form. `/login` opens on Sign in, `/register` on Create account.
class AuthPage extends StatefulWidget {
  const AuthPage({this.startInSignUp = false, super.key});

  final bool startInSignUp;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _signUp = widget.startInSignUp;
  UserRole _role = UserRole.public;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    context.read<AuthCubit>().clearError();
    _formKey.currentState?.reset();
    setState(() => _signUp = signUp);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthCubit>();

    if (!_signUp) {
      final ok = await auth.signIn(_email.text, _password.text);
      if (ok && mounted) context.go(AppRoutes.feed);
      return;
    }

    final ok = await auth.signUp(
      email: _email.text,
      password: _password.text,
      username: _username.text,
      role: _role,
    );
    if (!ok || !mounted) return;
    if (auth.state.needsEmailConfirmation) {
      context.go(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}');
    } else {
      context.go(AppRoutes.feed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return AuthScaffold(
          topBar: AuthStatusBar(
            label: 'INCOMING REPORTS',
            trailing: Row(
              children: [
                for (final c in [
                  AppColors.regionBreaking,
                  const Color(0xFFE0A800),
                  palette.verified,
                  AppColors.regionQuiet,
                ]) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
          stage: const AuthStage(),
          form: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthModeSwitch(signUp: _signUp, onChanged: _setMode),
                  const SizedBox(height: 12),
                  if (state.failure != null)
                    AuthErrorBanner(message: state.failure!.message),
                  if (_signUp) ...[
                    RolePicker(
                      value: _role,
                      onChanged: (r) => setState(() => _role = r),
                    ),
                    const SizedBox(height: 10),
                    AuthField(
                      controller: _username,
                      hint: 'Username',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      validator: (v) => _usernamePattern.hasMatch(v ?? '')
                          ? null
                          : '3–20 characters: letters, numbers or _',
                    ),
                    const SizedBox(height: 10),
                  ],
                  AuthField(
                    controller: _email,
                    hint: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) => (v ?? '').trim().contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  const SizedBox(height: 10),
                  AuthField(
                    controller: _password,
                    hint: _signUp ? 'Password (8+ characters)' : 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscurable: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    autofillHints: [
                      _signUp ? AutofillHints.newPassword : AutofillHints.password
                    ],
                    validator: (v) {
                      final value = v ?? '';
                      if (_signUp) {
                        return value.length >= 8 ? null : 'At least 8 characters';
                      }
                      return value.isEmpty ? 'Enter your password' : null;
                    },
                  ),
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          context.read<AuthCubit>().clearError();
                          context.push(AppRoutes.forgotPassword);
                        },
                        child: const Text('Forgot password?'),
                      ),
                    )
                  else
                    const SizedBox(height: 14),
                  AuthPrimaryButton(
                    label: !_signUp
                        ? 'SIGN IN'
                        : _role == UserRole.reporter
                            ? 'JOIN AS REPORTER'
                            : 'JOIN AS READER',
                    loading: state.isLoading,
                    onPressed: _submit,
                  ),
                  if (_signUp) ...[
                    const SizedBox(height: 12),
                    // TODO: link Terms and Privacy Policy once they exist.
                    Text.rich(
                      TextSpan(
                        text: 'By creating an account you agree to the ',
                        children: [
                          TextSpan(
                            text: 'Terms',
                            style: TextStyle(
                                color: palette.accent,
                                fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: palette.accent,
                                fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, height: 1.5, color: palette.muted),
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
