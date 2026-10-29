import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../cubits/e2ee_cubit.dart';

/// New phone (or reinstall) with a PIN backup on the account.
class RestoreMessagesPage extends StatefulWidget {
  const RestoreMessagesPage({super.key});

  @override
  State<RestoreMessagesPage> createState() => _RestoreMessagesPageState();
}

class _RestoreMessagesPageState extends State<RestoreMessagesPage> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    FocusScope.of(context).unfocus();
    final result = await context.read<E2eeCubit>().restore(_pin.text);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Messages restored')));
      return;
    }
    setState(() => _error = result.wiped
        ? 'Too many wrong tries — the backup was deleted. You can keep using messages with new keys.'
        : result.noBackup
            ? 'There’s no backup any more.'
            : result.attemptsLeft == null
                ? 'That didn’t work. Try again.'
                : 'Wrong PIN. ${result.attemptsLeft} tries left.');
  }

  Future<void> _startFresh() async {
    final palette = context.palette;
    final yes = await showSoftSheet<bool>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Start without your backup?',
                style: inter(18, weight: FontWeight.w600, color: Theme.of(sheet).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Older messages can’t be read on this phone, and the people you '
              'talk to will see that your security code changed.',
              textAlign: TextAlign.center,
              style: inter(15, color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            PillButton(label: 'Start fresh', onPressed: () => Navigator.of(sheet).pop(true)),
            TextButton(onPressed: () => Navigator.of(sheet).pop(false), child: const Text('Cancel')),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    await context.read<E2eeCubit>().startFresh();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final busy = context.select<E2eeCubit, bool>((c) => c.state.busy);
    return Scaffold(
      appBar: softAppBar(context, 'Restore messages'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 40),
          children: [
            Icon(Icons.lock_reset_rounded, size: 48, color: palette.accent),
            const SizedBox(height: 16),
            Text('Enter your backup PIN',
                textAlign: TextAlign.center,
                style: inter(20, weight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'It brings your encryption keys and recent messages to this phone.',
              textAlign: TextAlign.center,
              style: inter(15, color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            SoftField(
              label: 'PIN',
              controller: _pin,
              password: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              error: _error,
            ),
            const SizedBox(height: 20),
            PillButton(label: 'Restore', loading: busy, onPressed: _restore),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _startFresh,
              style: TextButton.styleFrom(foregroundColor: palette.muted),
              child: const Text('Forgot PIN? Start fresh'),
            ),
          ],
        ),
      ),
    );
  }
}
