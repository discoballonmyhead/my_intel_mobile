/// Names of the Postgres schemas, tables, RPCs and storage buckets exposed by
/// the backend. Centralised so a rename is a one-line change and the data
/// layer never hard-codes a raw string.
class DbSchemas {
  const DbSchemas._();
  static const String content = 'content';
  static const String identity = 'identity';
  static const String media = 'media';
  static const String moderation = 'moderation';
  static const String messaging = 'messaging';
  static const String admin = 'admin';
}

class DbTables {
  const DbTables._();

  // content
  static const String posts = 'posts';
  static const String likes = 'likes';
  static const String savedPosts = 'saved_posts';
  static const String reposts = 'reposts';
  static const String stories = 'stories';
  static const String storySources = 'story_sources';

  // identity
  static const String profiles = 'profiles';
  static const String follows = 'follows';
  static const String osintApplications = 'osint_applications';

  // media
  static const String videos = 'videos';
  static const String videoLikes = 'video_likes';
  static const String liveStreams = 'live_streams';

  // moderation
  static const String claims = 'claims';
  static const String communityNotes = 'community_notes';
  static const String feedback = 'feedback';
  static const String reports = 'reports';

  // messaging
  static const String conversations = 'conversations';
  static const String participants = 'participants';
  static const String messages = 'messages';

  // admin
  static const String userRoles = 'user_roles';
  static const String sanctions = 'sanctions';
  static const String auditLog = 'audit_log';
}

/// `public` schema functions callable through PostgREST rpc().
class DbRpc {
  const DbRpc._();
  static const String extractKeywords = 'extract_keywords';
  static const String keywordOverlapScore = 'keyword_overlap_score';
  static const String findSimilarPosts = 'find_similar_posts';
  static const String findSimilarStories = 'find_similar_stories';
  static const String upsertAuraPoints = 'upsert_aura_points';
}

class StorageBuckets {
  const StorageBuckets._();
  static const String mintMedia = 'mint-media';
  static const String videos = 'videos';
}

/// RPCs for editing / deleting posts (migration 02 + 10).
class PostRpc {
  const PostRpc._();
  static const String edit = 'post_edit';
  static const String delete = 'post_delete';
  static const String editHistory = 'post_get_edit_history';

  /// Post + attachments + poll in one transaction (migration 20261009).
  static const String create = 'social_create_post';
  static const String attachmentsForPosts = 'attachment_get_for_posts';
  static const String pollsForPosts = 'poll_get_for_posts';
  static const String pollVote = 'poll_vote';
}

/// RPCs for direct messages and groups (migration 04 + 10).
class MessagingRpc {
  const MessagingRpc._();
  static const String getOrCreateDirect = 'msg_get_or_create_direct';
  static const String createGroup = 'msg_create_group';
  static const String updateGroup = 'msg_update_group';
  static const String addMembers = 'msg_add_members';
  static const String removeMember = 'msg_remove_member';
  static const String leave = 'msg_leave_conversation';
  static const String send = 'msg_send';
  static const String edit = 'msg_edit';
  static const String delete = 'msg_delete';
  static const String deleteConversation = 'msg_delete_conversation';
  static const String markRead = 'msg_mark_read';
  static const String setMuted = 'msg_set_muted';
  static const String inbox = 'msg_get_inbox';
  static const String messages = 'msg_get_messages';
  static const String unreadTotal = 'msg_get_unread_total';
  static const String conversation = 'msg_get_conversation';
}

/// RPCs for user reports and the moderator queue (migration 05).
class ReportRpc {
  const ReportRpc._();
  static const String report = 'mod_report';
  static const String myReports = 'mod_get_my_reports';
  static const String queue = 'mod_get_report_queue';
  static const String forTarget = 'mod_get_reports_for_target';
  static const String claimTarget = 'mod_claim_target';
  static const String resolveTarget = 'mod_resolve_target';
  static const String removePost = 'mod_remove_post';
  static const String restorePost = 'mod_restore_post';
  static const String setPostVisibility = 'mod_set_post_visibility';
  static const String removeMessage = 'mod_remove_message';
  static const String warnUser = 'mod_warn_user';
}

/// RPCs for the admin console (migration 06 + 07).
class AdminRpc {
  const AdminRpc._();
  static const String approveOsint = 'admin_approve_osint';
  static const String declineOsint = 'admin_decline_osint';
  static const String revokeOsint = 'admin_revoke_osint';
  static const String osintApplications = 'admin_get_osint_applications';
  static const String grantRole = 'admin_grant_role';
  static const String revokeRole = 'admin_revoke_role';
  static const String banUser = 'admin_ban_user';
  static const String unbanUser = 'admin_unban_user';
  static const String liftSanction = 'admin_lift_sanction';
  static const String users = 'admin_get_users';
  static const String userDetail = 'admin_get_user_detail';
  static const String auditLog = 'admin_get_audit_log';
  static const String stats = 'admin_get_stats';
  static const String deleteAccount = 'admin_delete_account';
}

/// RPCs every signed-in user calls about their own account.
class AccountRpc {
  const AccountRpc._();
  static const String myAccess = 'auth_get_my_access';
  static const String deleteSelf = 'account_delete_self';

  /// Exact phrase `account_delete_self` requires.
  static const String deleteConfirmation = 'DELETE MY ACCOUNT';
}
