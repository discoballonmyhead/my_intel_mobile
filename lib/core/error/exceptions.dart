/// Exceptions thrown by the data layer. They never escape a repository — the
/// repository catches them and converts them into a [Failure].
class ServerException implements Exception {
  const ServerException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'ServerException($code): $message';
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'AuthException($code): $message';
}

class NotFoundException implements Exception {
  const NotFoundException(this.message);
  final String message;
}

class PermissionException implements Exception {
  const PermissionException(this.message);
  final String message;
}

/// Input the server rejected as invalid (Postgres errcode 22023).
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
}

class CacheException implements Exception {
  const CacheException(this.message);
  final String message;
}

/// The server wants proof the staff member is still at the keyboard: a fresh
/// password sign-in (`reauthentication_required`) or a two-step code
/// (`mfa_required`). The admin app asks and retries the action once.
class ReauthRequiredException implements Exception {
  const ReauthRequiredException(this.message, {this.needsMfa = false});
  final String message;
  final bool needsMfa;
}

/// The governance key was rotated while this phone had the old one cached
/// (`escrow_key_outdated`): reseal with the new key and send again.
class StaleGovernanceKeyException implements Exception {
  const StaleGovernanceKeyException(this.message);
  final String message;
}
