import '../../../../core/utils/result.dart';
import '../entities/credibility_report.dart';

abstract interface class CredibilityRepository {
  /// Recomputes [userId]'s score (also saved to the leaderboard server-side).
  /// `Ok(null)` for users who aren't OSINT analysts.
  Future<Result<CredibilityReport?>> getCredibility(String userId);
}
