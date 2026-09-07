import 'package:equatable/equatable.dart';

/// The authenticated identity, independent of Supabase's `User` type.
/// The profile row (username, role, score) is a separate entity owned by the
/// profile feature — this one only describes who is signed in.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.username,
    this.emailConfirmed = false,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? username;
  final bool emailConfirmed;
  final DateTime? createdAt;

  /// Fallback display name used before the profile row loads.
  String get displayName =>
      username ?? (email.contains('@') ? email.split('@').first : email);

  @override
  List<Object?> get props => [id, email, username, emailConfirmed, createdAt];
}

/// Result of a sign-up attempt. When email confirmation is on, Supabase
/// returns no session and the user must verify before signing in.
class SignUpResult extends Equatable {
  const SignUpResult({required this.needsEmailConfirmation, this.user});

  final bool needsEmailConfirmation;
  final AuthUser? user;

  @override
  List<Object?> get props => [needsEmailConfirmation, user];
}

enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }
