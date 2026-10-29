import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../cubits/e2ee_cubit.dart';

/// Top of the inbox: "Restore your messages" on a new phone, or a nudge to
/// turn on the PIN backup. Nothing when all is well.
class E2eeInboxBanner extends StatelessWidget {
  const E2eeInboxBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<E2eeCubit, E2eeState>(
      builder: (context, state) {
        final palette = context.palette;
        final (IconData icon, String title, String body, Color tint)? content = state.needsRestore
            ? (Icons.restore_rounded, 'Restore your messages',
                'Enter your backup PIN to read your conversations here.', palette.accent)
            : state.error != null
                ? (Icons.cloud_off_rounded, 'Secure messaging isn’t ready', state.error!, palette.warn)
                : state.shouldOfferBackup
                    ? (Icons.key_rounded, 'Protect your messages',
                        'Set a PIN so a new phone can restore them.', palette.verified)
                    : null;
        if (content == null) return const SizedBox.shrink();
        final (icon, title, body, tint) = content;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Material(
            color: tint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (state.error != null) {
                  context.read<E2eeCubit>().retry();
                } else {
                  context.push(state.needsRestore ? AppRoutes.restoreMessages : AppRoutes.secureMessaging);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(icon, color: tint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: inter(15, weight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(body, style: inter(13, color: palette.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.muted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One line above the composer saying whether the chat is encrypted.
class EncryptionNotice extends StatelessWidget {
  const EncryptionNotice({required this.encrypted, this.waitingFor, super.key});

  final bool encrypted;

  /// Names of people still on an old app (messages to them aren't encrypted yet).
  final List<String>? waitingFor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = waitingFor ?? const [];
    final text = encrypted
        ? (pending.isEmpty
            ? 'Messages are end-to-end encrypted'
            : '${pending.join(', ')} can’t read new messages until they update the app')
        : pending.isEmpty
            ? 'Messages will be end-to-end encrypted'
            : 'Not encrypted yet: ${pending.join(', ')} uses an older app';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(encrypted || pending.isEmpty ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 13, color: encrypted || pending.isEmpty ? palette.verified : palette.warn),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: inter(12, color: palette.muted)),
          ),
        ],
      ),
    );
  }
}

/// "Verify security code": the 60-digit safety number to compare in person.
class SafetyNumberSheet extends StatelessWidget {
  const SafetyNumberSheet._({required this.userId, required this.name});

  final String userId;
  final String name;

  static Future<void> show(BuildContext context, {required String userId, required String name}) =>
      showSoftSheet<void>(
        context,
        (_) => BlocProvider.value(
          value: context.read<E2eeCubit>(),
          child: SafetyNumberSheet._(userId: userId, name: name),
        ),
      );

  Future<(String?, ({bool verified, bool changed}))> _load(E2eeCubit cubit) async =>
      (await cubit.safetyNumber(userId), await cubit.trustOf(userId));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cubit = context.read<E2eeCubit>();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: FutureBuilder<(String?, ({bool verified, bool changed}))>(
        future: _load(cubit),
        builder: (context, snap) {
          final number = snap.data?.$1;
          final trust = snap.data?.$2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Security code with $name',
                  style: inter(18, weight: FontWeight.w600, color: onSurface)),
              const SizedBox(height: 8),
              Text(
                'Compare these numbers with $name in person or on a call. '
                'If they match, nobody can read your messages in between.',
                textAlign: TextAlign.center,
                style: inter(14, color: palette.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
              else if (number == null)
                Text('$name hasn’t set up encryption yet.', style: inter(15, color: palette.muted))
              else ...[
                Text(number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 20, height: 1.6,
                        letterSpacing: 1.5, color: onSurface)),
                const SizedBox(height: 16),
                if (trust?.changed == true && trust?.verified != true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('This code changed recently (new phone or reinstall).',
                        style: inter(13, color: palette.warn)),
                  ),
                if (trust?.verified == true)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, color: palette.verified, size: 18),
                      const SizedBox(width: 6),
                      Text('Verified', style: inter(14, weight: FontWeight.w600, color: palette.verified)),
                    ],
                  )
                else
                  PillButton(
                    label: 'Mark as verified',
                    soft: true,
                    onPressed: () async {
                      await cubit.markVerified(userId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
