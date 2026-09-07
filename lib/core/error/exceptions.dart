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

class CacheException implements Exception {
  const CacheException(this.message);
  final String message;
}
