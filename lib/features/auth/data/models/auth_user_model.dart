import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/auth_user.dart';

/// Adapts Supabase's `User` into the domain [AuthUser]. Keeping the mapping in
/// the data layer means no other layer imports the Supabase SDK.
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    super.username,
    super.emailConfirmed,
    super.createdAt,
    super.pendingEmail,
  });

  factory AuthUserModel.fromSupabase(sb.User user) {
    return AuthUserModel(
      id: user.id,
      email: user.email ?? '',
      username: user.userMetadata?['username'] as String?,
      emailConfirmed: user.emailConfirmedAt != null,
      createdAt: DateTime.tryParse(user.createdAt)?.toUtc(),
      pendingEmail: (user.newEmail?.isNotEmpty ?? false) ? user.newEmail : null,
    );
  }
}
