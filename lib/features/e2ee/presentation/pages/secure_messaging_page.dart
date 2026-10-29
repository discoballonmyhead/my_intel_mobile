import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../cubits/e2ee_cubit.dart';

/// Settings → Account → Secure messaging: what's encrypted, and the PIN
/// backup that brings keys and message history to a new phone.
class SecureMessagingPage extends StatelessWidget {
  const SecureMessagingPage({super.key});

  Future<void> _setPin(BuildContext context) async {
    final saved = await showSoftSheet<bool>(context, (_) => BlocProvider.value(
          value: context.read<E2eeCubit>(),
          child: const _PinSheet(),
        ));
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup saved')));
    }
  }

  Future<void> _turnOff(BuildContext context) async {
    final palette = context.palette;
    final yes = await showSoftSheet<bool>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Turn off the backup?',
                style: inter(18, weight: FontWeight.w600, color: Theme.of(sheet).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('If you lose this phone, your messages can’t be brought back.',
                textAlign: TextAlign.center, style: inter(15, color: palette.muted)),
            const SizedBox(height: 24),
            PillButton(label: 'Turn off', onPressed: () => Navigator.of(sheet).pop(true)),
            TextButton(onPressed: () => Navigator.of(sheet).pop(false), child: const Text('Cancel')),
          ],
        ),
      ),
    );
    if (yes == true && context.mounted) await context.read<E2eeCubit>().deleteBackup();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return BlocBuilder<E2eeCubit, E2eeState>(
      builder: (context, state) {
        return Scaffold(
          appBar: softAppBar(context, 'Secure messaging'),
          body: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_rounded, color: palette.verified),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.isReady
                                  ? 'Your messages are end-to-end encrypted'
                                  : state.needsRestore
                                      ? 'Restore your messages'
                                      : 'Setting up encryption…',
                              style: inter(16, weight: FontWeight.w600, color: onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Only you and the people you message can read them. '
                              'The keys stay on this phone; MINT’s servers only '
                              'store scrambled text.',
                              style: inter(13, color: palette.muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Not set up yet',
                      body: state.error!,
                      action: 'Try again',
                      onAction: context.read<E2eeCubit>().retry,
                    ),
                  ),
                if (state.needsRestore)
                  SettingsGroup([
                    SettingsRow(
                      title: 'Restore with your PIN',
                      subtitle: 'Brings back your keys and recent messages',
                      icon: Icons.restore_rounded,
                      onTap: () => context.push(AppRoutes.restoreMessages),
                    ),
                  ]),
                if (state.isReady) ...[
                  const SectionLabel('PIN backup'),
                  SettingsGroup([
                    SettingsRow(
                      title: state.hasBackup == true ? 'Change PIN' : 'Turn on PIN backup',
                      subtitle: state.hasBackup == true
                          ? 'Backup is on'
                          : 'Without it, a new phone can’t read old messages',
                      subtitleColor: state.hasBackup == true ? null : palette.warn,
                      icon: Icons.key_rounded,
                      onTap: state.busy ? null : () => _setPin(context),
                    ),
                    if (state.hasBackup == true)
                      SettingsRow(
                        title: 'Turn off backup',
                        icon: Icons.delete_outline_rounded,
                        iconColor: palette.accent,
                        titleColor: palette.accent,
                        chevron: false,
                        onTap: state.busy ? null : () => _turnOff(context),
                      ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'The PIN never leaves this phone. After 10 wrong tries the '
                      'backup is deleted, so nobody can guess it.',
                      style: inter(13, color: palette.muted, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PinSheet extends StatefulWidget {
  const _PinSheet();

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pin.text != _again.text) {
      setState(() => _error = 'The PINs don’t match.');
      return;
    }
    final error = await context.read<E2eeCubit>().createBackup(_pin.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<E2eeCubit, bool>((c) => c.state.busy);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choose a backup PIN',
              textAlign: TextAlign.center,
              style: inter(18, weight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 16),
          SoftField(label: 'PIN', controller: _pin, password: true,
              keyboardType: TextInputType.number, autofocus: true,
              help: 'At least 6 digits. You’ll need it on a new phone.'),
          const SizedBox(height: 12),
          SoftField(label: 'PIN again', controller: _again, password: true,
              keyboardType: TextInputType.number, error: _error),
          const SizedBox(height: 20),
          PillButton(label: 'Save backup', loading: busy, onPressed: _save),
        ],
      ),
    );
  }
}
