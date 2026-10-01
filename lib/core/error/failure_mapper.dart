import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'exceptions.dart';
import 'failures.dart';
import '../utils/result.dart';

/// Every repository funnels its calls through [guard] so exception-to-failure
/// mapping is written once instead of in each method.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Ok(await action());
  } on PermissionException catch (e) {
    return Err(PermissionFailure(e.message));
  } on ValidationException catch (e) {
    return Err(ValidationFailure(e.message));
  } on NotFoundException catch (e) {
    return Err(NotFoundFailure(e.message));
  } on AuthException catch (e) {
    return Err(AuthFailure(e.message, code: e.code));
  } on ServerException catch (e) {
    return Err(mapPostgrestCode(e));
  } on SocketException {
    return const Err(NetworkFailure());
  } on TimeoutException {
    return const Err(NetworkFailure('The request timed out.'));
  } catch (e, stack) {
    // Anything unmapped (a bad cast, a raw PostgrestException…) still shows
    // the generic message, but is logged so the cause is visible in the console.
    dev.log('Unexpected error: $e', name: 'guard', error: e, stackTrace: stack);
    return const Err(UnexpectedFailure());
  }
}

/// Translates the Postgres error codes this schema actually produces.
Failure mapPostgrestCode(ServerException e) {
  return switch (e.code) {
    // insufficient_privilege — an RLS policy rejected the statement.
    '42501' => const PermissionFailure(),
    // unique_violation
    '23505' => const ServerFailure('That already exists.'),
    // foreign_key_violation
    '23503' => const ServerFailure('Referenced record no longer exists.'),
    // not_null_violation
    '23502' => const ValidationFailure('A required field was missing.'),
    // PostgREST: no rows returned for .single()
    'PGRST116' => const NotFoundFailure(),
    _ => ServerFailure(e.message, code: e.code),
  };
}
