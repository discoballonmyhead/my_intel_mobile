import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/profile_cubit.dart';
import 'profile_ui.dart';

/// About me needs a `bio` column on identity.profiles. The field is built but
/// stays hidden until the backend has it.
const bool kAboutMeEnabled = false;
const int kAboutMeMaxLength = 160;

/// Bottom sheet to change the username (and, later, About me). Returns true
/// when something was saved.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({required this.username, super.key});

  final String username;

  static Future<bool> show(BuildContext context, String username) async {
    final cubit = context.read<ProfileCubit>();
    final saved = await showSoftSheet<bool>(
      context,
      (_) => BlocProvider.value(
        value: cubit,
        child: EditProfileSheet(username: username),
      ),
    );
    return saved ?? false;
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final _username = TextEditingController(text: widget.username);
  final _bio = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _username.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Use at least 3 characters.');
      return;
    }
    if (name == widget.username) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final cubit = context.read<ProfileCubit>();
    final ok = await cubit.updateUsername(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = cubit.state.failure?.message ?? 'Couldn’t save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Edit profile',
              style: inter(18,
                  weight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          SoftField(
            label: 'Username',
            controller: _username,
            error: _error,
            help: 'Your channel link changes too.',
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (kAboutMeEnabled)
            ValueListenableBuilder(
              valueListenable: _bio,
              builder: (_, value, __) => SoftField(
                label: 'About me',
                controller: _bio,
                maxLines: 3,
                hint: 'A line about what you follow or report on',
                help: '${value.text.length} / $kAboutMeMaxLength',
              ),
            ),
          const SizedBox(height: 8),
          PillButton(label: 'Save', onPressed: _save, loading: _saving),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
                foregroundColor: palette.muted,
                textStyle: inter(15, weight: FontWeight.w500)),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
