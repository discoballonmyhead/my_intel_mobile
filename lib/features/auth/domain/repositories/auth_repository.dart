import '../../../../core/constants/user_role.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';

/// The domain's view of authentication. The presentation layer depends on this
/// interface only, so Supabase can be swapped without touching a single page.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, token refresh and password-recovery links.
  /// Fires immediately with the current session, so it doubles as the initial
  /// load signal.
  Stream<AuthUser?> get authStateChanges;

  /// Separate from [authStateChanges] because a recovery deep-link must route
  /// the user to the reset screen rather than into the app.
  Stream<AuthStatus> get authStatusChanges;

  AuthUser? get currentUser;

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<SignUpResult>> signUp({
    required String email,
    required String password,
    required String username,
    UserRole role = UserRole.public,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);

  Future<Result<void>> updatePassword(String newPassword);

  Future<Result<void>> resendVerification(String email);

  /// Confirms the signed-in user's current password.
  Future<Result<void>> verifyPassword(String password);

  /// Sends a confirmation link to [newEmail]; the change applies once tapped.
  Future<Result<void>> changeEmail(String newEmail);
}
