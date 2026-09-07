import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../constants/db_constants.dart';

/// Single entry point to Supabase.
///
/// `client.schema(name)` does not fetch anything. It returns a thin local
/// builder that sets PostgREST's `Accept-Profile` / `Content-Profile` header
/// on the next request, which is how a query is pointed at a schema other than
/// `public`. The four getters below are built once in the constructor and
/// reused, so a call site costs nothing beyond the query it was going to make.
///
/// They exist because the backend splits tables across four schemas and
/// PostgREST cannot embed across a schema boundary: `content.posts.author_id`
/// points into `identity.profiles`, and no `select('*, profiles(*)')` will
/// resolve it. Those joins are done in the data sources by batching a second
/// profile fetch and merging. Naming the schema at every call site keeps that
/// constraint visible instead of surprising the next person who tries to embed.
///
/// For any of this to work the four schemas must be listed under
/// *Project Settings → API → Exposed schemas*. PostgREST only serves schemas
/// it has been told about, and an unexposed one fails at request time rather
/// than at build time.
class SupabaseService {
  SupabaseService(this._client)
      : content = _client.schema(DbSchemas.content),
        identity = _client.schema(DbSchemas.identity),
        media = _client.schema(DbSchemas.media),
        moderation = _client.schema(DbSchemas.moderation);

  final SupabaseClient _client;

  static Future<void> initialize() async {
    assert(
      Env.isConfigured,
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be passed with '
      '--dart-define.',
    );
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;
  SupabaseStorageClient get storage => _client.storage;

  String? get currentUserId => _client.auth.currentUser?.id;
  bool get isSignedIn => _client.auth.currentUser != null;

  /// Query builders scoped to each schema. Header switches, not connections.
  final SupabaseQuerySchema content;
  final SupabaseQuerySchema identity;
  final SupabaseQuerySchema media;
  final SupabaseQuerySchema moderation;

  /// RPCs live in `public`, so they go through the default client. This is the
  /// one place a query can cross schema boundaries freely, which is why the
  /// heavier reads are worth moving into functions.
  Future<T> rpc<T>(String fn, {Map<String, dynamic>? params}) =>
      _client.rpc<T>(fn, params: params);

  /// Realtime channel for postgres changes on a non-public schema.
  ///
  /// Realtime is a separate grant from PostgREST: a table only emits changes
  /// once it is added to the `supabase_realtime` publication.
  RealtimeChannel channel(String name) => _client.channel(name);

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);
}
