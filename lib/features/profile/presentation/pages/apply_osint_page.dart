import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/usecases/apply_for_osint.dart';
import '../providers/profile_provider.dart';

/// Writes to `identity.osint_applications`. An admin reviews it; the role
/// itself is only ever changed server-side.
class ApplyOsintPage extends StatefulWidget {
  const ApplyOsintPage({super.key});

  @override
  State<ApplyOsintPage> createState() => _ApplyOsintPageState();
}

class _ApplyOsintPageState extends State<ApplyOsintPage> {
  final _formKey = GlobalKey<FormState>();
  final _channel = TextEditingController();
  final _handle = TextEditingController();
  final _portfolio = TextEditingController();
  final _why = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadApplication();
    });
  }

  @override
  void dispose() {
    _channel.dispose();
    _handle.dispose();
    _portfolio.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final provider = context.read<ProfileProvider>();
    final ok = await provider.applyForOsint(OsintApplicationParams(
      channelName: _channel.text,
      handle: _handle.text,
      portfolio: _portfolio.text,
      why: _why.text,
    ));
    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Application submitted for review.'
              : provider.failure?.message ?? 'Could not submit.',
        ),
      ),
    );
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = context.watch<ProfileProvider>().application;

    return Scaffold(
      appBar: AppBar(title: const Text('ANALYST ACCESS')),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            if (existing != null && existing.isPending)
              Text(
                'Your application for "${existing.channelName}" is pending review.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              Text(
                'Analysts can publish intelligence reports that cluster into '
                'stories. Tell us about your work.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _channel,
                      decoration: const InputDecoration(hintText: 'Channel name'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _handle,
                      decoration: const InputDecoration(
                        hintText: 'Handle (e.g. @yourname)',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _portfolio,
                      decoration: const InputDecoration(
                        hintText: 'Portfolio or profile link (optional)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _why,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Why do you want analyst access?',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SUBMIT APPLICATION'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
