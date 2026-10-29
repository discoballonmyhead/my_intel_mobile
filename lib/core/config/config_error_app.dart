import 'package:flutter/material.dart';

/// Shown instead of the app when the build was made without its
/// configuration, or with a server-only key that must never ship in an app.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({this.serverKey = false, super.key});

  final bool serverKey;

  @override
  Widget build(BuildContext context) {
    final message = serverKey
        ? 'This build contains a Supabase SECRET / service-role key. '
            'Use the publishable key (sb_publishable_…) and rotate the secret '
            'key in the Supabase dashboard.'
        : 'Missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY.\n\n'
            'Run with:\nflutter run --dart-define-from-file=env/dev.json';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
