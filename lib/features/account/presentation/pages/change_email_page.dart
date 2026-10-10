import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/usecases/account_security.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

/// New email and password, then "Check your inbox". The address changes once
/// the link in the email is tapped.
class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _saving = false;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _current => context.read<AuthCubit>().state.user?.email ?? '';

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _emailError = null;
      _passwordError = null;
    });
    final result = await sl<ChangeEmail>()(ChangeEmailParams(
      currentEmail: _current,
      newEmail: _email.text,
      password: _password.text,
    ));
    if (!mounted) return;
    final failure = result.failureOrNull;
    setState(() {
      _saving = false;
      if (failure == null) {
        _sentTo = _email.text.trim();
      } else if (failure.code == wrongPasswordCode) {
        _passwordError = failure.message;
      } else {
        _emailError = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final sent = _sentTo;

    if (sent != null) {
      return Scaffold(
        appBar: softAppBar(context, ''),
        body: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 40),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration:
                      BoxDecoration(color: palette.surface2, shape: BoxShape.circle),
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 42, color: palette.accent),
                ),
              ),
              const SizedBox(height: 28),
              Text('Check your inbox',
                  textAlign: TextAlign.center,
                  style: inter(22, weight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 12),
              Text(
                'We sent a link to $sent. Tap it to finish changing your email. '
                'Until then, keep signing in with $_current.',
                textAlign: TextAlign.center,
                style: inter(15, color: palette.muted, height: 1.45),
              ),
              const SizedBox(height: 28),
              PillButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _send,
                style: TextButton.styleFrom(
                    foregroundColor: palette.accent,
                    textStyle: inter(15, weight: FontWeight.w500)),
                child: const Text('Resend link'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: softAppBar(context, 'Change email'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Text('Current email',
                  style: inter(13, weight: FontWeight.w600, color: palette.muted)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 22),
              child: Text(_current, style: inter(17, color: onSurface)),
            ),
            SoftField(
              label: 'New email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              error: _emailError,
            ),
            SoftField(
              label: 'Password',
              controller: _password,
              password: true,
              error: _passwordError,
              help: 'To keep your account safe.',
            ),
            const SizedBox(height: 8),
            PillButton(
                label: 'Send confirmation link', onPressed: _send, loading: _saving),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'We’ll email a link to the new address. Your email changes once you tap it.',
                style: inter(13, color: palette.muted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
