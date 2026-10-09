import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/usecases/account_security.dart';
import '../../../auth/domain/usecases/reset_password.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

/// Current password, new password twice. On success it goes back to Account
/// with "Password updated".
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _currentError = null;
      _formError = null;
    });
    final result = await sl<ChangePassword>()(ChangePasswordParams(
      current: _current.text,
      newPassword: _new.text,
      confirm: _confirm.text,
    ));
    if (!mounted) return;
    final failure = result.failureOrNull;
    if (failure == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
      return;
    }
    setState(() {
      _saving = false;
      if (failure.code == wrongPasswordCode) {
        _currentError = failure.message;
      } else {
        _formError = failure.message;
      }
    });
  }

  Future<void> _forgot() async {
    final email = context.read<AuthCubit>().state.user?.email;
    if (email == null) return;
    final result = await sl<SendPasswordReset>()(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.failureOrNull?.message ??
          'We sent a reset link to $email.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: softAppBar(context, 'Change password'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
          children: [
            SoftField(
              label: 'Current password',
              id: 'current-password',
              controller: _current,
              password: true,
              error: _currentError,
              onChanged: (_) {
                if (_currentError != null) setState(() => _currentError = null);
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _forgot,
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  textStyle: inter(14, weight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: const Text('Forgot your password?'),
              ),
            ),
            const SizedBox(height: 8),
            SoftField(
              label: 'New password',
              id: 'new-password',
              controller: _new,
              password: true,
              help: 'At least 8 characters.',
            ),
            SoftField(
              label: 'Confirm new password',
              id: 'confirm-password',
              controller: _confirm,
              password: true,
              error: _formError,
            ),
            const SizedBox(height: 8),
            PillButton(label: 'Update password', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
