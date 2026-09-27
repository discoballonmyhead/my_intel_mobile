import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/exceptions.dart' as ex;
import '../error/rpc_error_messages.dart';

/// Runs a Supabase call and converts [PostgrestException] into the typed
/// exceptions `guard()` understands, with the SQL error key translated into
/// readable copy. Every new data source goes through this so errors raised by
/// the RPCs (`account_restricted`, `edit_window_expired`, …) reach the UI
/// intact instead of collapsing into "Something went wrong".
Future<T> runRpc<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on PostgrestException catch (e) {
    final message = RpcErrorMessages.describe(e.message);
    switch (e.code) {
      case '42501':
        throw ex.PermissionException(message);
      case 'P0002':
      case 'PGRST116':
        throw ex.NotFoundException(message);
      case '22023':
      case '22P02':
        throw ex.ValidationException(message);
      case '28000':
        throw ex.AuthException(message, code: e.code);
      default:
        throw ex.ServerException(message, code: e.code);
    }
  }
}

/// Casts a PostgREST rpc() payload that may be a list, a single row or null.
List<Map<String, dynamic>> asRows(Object? response) {
  if (response == null) return const [];
  if (response is List) {
    return response.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
  if (response is Map) return [Map<String, dynamic>.from(response)];
  return const [];
}

/// Casts a PostgREST rpc() payload that is expected to be one object.
Map<String, dynamic>? asRow(Object? response) {
  final rows = asRows(response);
  return rows.isEmpty ? null : rows.first;
}

/// bigint columns can arrive as int or (from jsonb) as num/String.
int? asInt(Object? value) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
