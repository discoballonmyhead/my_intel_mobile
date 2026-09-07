import '../config/env.dart';
import 'supabase_service.dart';

/// Thin seam over [SupabaseService.initialize] so `main` does not import the
/// Supabase package directly and tests can skip the network entirely.
class SupabaseServiceBootstrap {
  const SupabaseServiceBootstrap._();

  static Future<void> run() async {
    if (!Env.isConfigured) return;
    await SupabaseService.initialize();
  }
}
