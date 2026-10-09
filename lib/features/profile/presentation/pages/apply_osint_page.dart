import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/usecases/apply_for_osint.dart';
import '../widgets/profile_ui.dart';

class ApplyOsintPage extends StatefulWidget {
  const ApplyOsintPage({super.key});

  @override
  State<ApplyOsintPage> createState() => _ApplyOsintPageState();
}

class _ApplyOsintPageState extends State<ApplyOsintPage> {
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

  String? _channelError;
  String? _handleError;

  void _submit() {
    setState(() {
      _channelError = _channel.text.trim().isEmpty ? 'Add your channel name.' : null;
      _handleError = _handle.text.trim().isEmpty ? 'Add your handle.' : null;
    });
    if (_channelError != null || _handleError != null) return;

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
            const SnackBar(content: Text('Application sent')),
          );
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        final existing = state.application;
        final sending = state.isSubmitting;

        final muted = context.palette.muted;
        return Scaffold(
          appBar: softAppBar(context, 'Become an analyst'),
          body: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
              children: [
                if (existing != null && existing.isPending)
                  Text(
                    'Your application for \u201c${existing.channelName}\u201d is in review. '
                    'We\u2019ll let you know when a moderator has looked at it.',
                    style: inter(15, color: muted, height: 1.45),
                  )
                else if (existing != null && !existing.canReapply())
                  Text(
                    'Your last application wasn\u2019t approved. You can apply '
                    'again from ${DateFormat('d MMM yyyy').format(existing.reapplyAvailableAt!.toLocal())}.',
                    style: inter(15, color: muted, height: 1.45),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 22),
                    child: Text(
                      'Analysts publish intel that clusters into stories. Tell us about your work.',
                      style: inter(15, color: muted, height: 1.45),
                    ),
                  ),
                  SoftField(
                      label: 'Channel name',
                      controller: _channel,
                      hint: 'e.g. Gulf Watch',
                      error: _channelError),
                  SoftField(
                      label: 'Handle',
                      controller: _handle,
                      hint: '@yourname',
                      error: _handleError),
                  SoftField(
                      label: 'Portfolio or profile link (optional)',
                      controller: _portfolio,
                      hint: 'https://',
                      keyboardType: TextInputType.url),
                  SoftField(
                      label: 'Why do you want to be an analyst?',
                      controller: _why,
                      hint: 'A few lines about your experience',
                      maxLines: 4),
                  const SizedBox(height: 8),
                  PillButton(
                      label: 'Submit application',
                      onPressed: _submit,
                      loading: sending),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
