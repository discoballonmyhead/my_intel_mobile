import 'package:mint/core/baboinki/shabunki.dart';

/// Compile-time configuration.
///
/// Supply values with `--dart-define`:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
class Env {
  const Env._();

  static const String supabaseUrl = supaabseUrl2;

  /// The browser-safe key. Supabase's newer `sb_publishable_...` keys replace
  /// the legacy JWT anon key; both are accepted by the same parameter, so the
  /// legacy define is still read as a fallback and existing setups keep
  /// working.
  static const String supabasePublishableKey = supabasepublishablekey1;

  /// Edge function used by the story composer for AI headline/summary work.
  static const String anthropicProxyPath = '/functions/v1/anthropic-proxy';

  /// The web client, used to build shareable links (e.g. a post's
  /// `/feed?highlight=<id>`, the same link the web app's Share copies).
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://signit-app.vercel.app',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
