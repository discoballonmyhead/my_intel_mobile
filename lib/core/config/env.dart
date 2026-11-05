import 'dart:convert';

/// Compile-time configuration. Nothing secret is written in the code: every
/// value comes from `--dart-define` / `--dart-define-from-file` at build time.
///
/// Local setup (the file is git-ignored, see `env/README.md`):
///   cp env/env.example.json env/dev.json   # fill in your own values
///   flutter run --dart-define-from-file=env/dev.json
///
/// Only *client-safe* values belong here. The Supabase publishable key is
/// designed to ship inside apps (row-level security protects the data), but it
/// is still kept out of source control so it can be rotated per environment.
/// Server secrets (service-role key, Anthropic key) live only in Supabase
/// edge-function secrets and must never be passed to the app.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// `sb_publishable_...`. The legacy JWT anon key is still read as a
  /// fallback so older setups keep working.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// Edge function used by the story composer for AI headline/summary work.
  static const String anthropicProxyPath = '/functions/v1/anthropic-proxy';

  /// The web client, used to build shareable links (e.g. a post's
  /// `/feed?highlight=<id>`, the same link the web app's Share copies).
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://signit-app.vercel.app',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;

  /// Refuses keys that must never be inside an app build.
  static bool get usesServerKey =>
      supabasePublishableKey.startsWith('sb_secret_') ||
      _jwtRole(supabasePublishableKey) == 'service_role';

  static String? _jwtRole(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return null;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      return claims is Map ? claims['role'] as String? : null;
    } on FormatException {
      return null;
    }
  }
}
