import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/usecases/apply_for_osint.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadApplication();
  }

  @override
  void dispose() {
    _channel.dispose();
    _handle.dispose();
    _portfolio.dispose();
    _why.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ProfileCubit>().applyForOsint(
          OsintApplicationParams(
            channelName: _channel.text,
            handle: _handle.text,
            portfolio: _portfolio.text,
            why: _why.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (prev, current) => prev.isSubmitting && !current.isSubmitting,
      listener: (context, state) {
        if (state.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.failure!.message)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted for review.')),
          );
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        final existing = state.application;
        final sending = state.isSubmitting;

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
                          decoration:
                              const InputDecoration(hintText: 'Channel name'),
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
                    onPressed: sending ? null : _submit,
                    child: sending
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
      },
    );
  }
}
