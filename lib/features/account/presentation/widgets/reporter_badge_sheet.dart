import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../data/datasources/badge_request_data_source.dart';

/// "Request the Reporter badge": journalists who publish articles and go
/// live with their sources. Reviewed by staff in the admin app.
class ReporterBadgeSheet extends StatefulWidget {
  const ReporterBadgeSheet._();

  static Future<void> show(BuildContext context) =>
      showSoftSheet<void>(context, (_) => const ReporterBadgeSheet._());

  @override
  State<ReporterBadgeSheet> createState() => _ReporterBadgeSheetState();
}

class _ReporterBadgeSheetState extends State<ReporterBadgeSheet> {
  final _note = TextEditingController();
  final _links = TextEditingController();
  String? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _links.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await sl<BadgeRequests>().mine();
    if (!mounted) return;
    final latest = (result.valueOrNull ?? const [])
        .where((r) => r['badge'] == 'reporter')
        .firstOrNull;
    setState(() => _status = latest?['status'] as String?);
  }

  Future<void> _send() async {
    final links = _links.text
        .split(RegExp(r'[\s,]+'))
        .map((l) => l.trim())
        .where((l) => l.startsWith('http'))
        .take(10)
        .toList();
    if (_note.text.trim().isEmpty && links.isEmpty) {
      setState(() => _error = 'Tell us about your work or add a link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await sl<BadgeRequests>().request('reporter', note: _note.text.trim(), links: links);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.failureOrNull?.message;
      if (result.isOk) _status = 'pending';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reporter badge',
              textAlign: TextAlign.center,
              style: inter(18, weight: FontWeight.w600, color: onSurface)),
          const SizedBox(height: 8),
          Text(
            'Reporters publish long articles and go live, citing their sources. '
            'Tell us where you report and our team will review it.',
            textAlign: TextAlign.center,
            style: inter(14, color: palette.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_status == 'pending')
            Text('Your request is in review.',
                textAlign: TextAlign.center, style: inter(15, color: palette.verified))
          else if (_status == 'approved')
            Text('You have the Reporter badge.',
                textAlign: TextAlign.center, style: inter(15, color: palette.verified))
          else ...[
            if (_status == 'rejected')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Your last request wasn’t approved. You can send a new one.',
                    textAlign: TextAlign.center, style: inter(13, color: palette.warn)),
              ),
            SoftField(label: 'About your reporting', controller: _note, maxLines: 4,
                hint: 'Outlet, beat, years of experience'),
            SoftField(label: 'Links to your work', controller: _links, maxLines: 3,
                hint: 'https://…  (one per line)', keyboardType: TextInputType.url, error: _error),
            const SizedBox(height: 8),
            PillButton(label: 'Send request', loading: _busy, onPressed: _busy ? null : _send),
          ],
        ],
      ),
    );
  }
}
