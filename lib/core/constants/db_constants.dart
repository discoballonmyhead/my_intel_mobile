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
  static const String comments = 'comments';

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
/// The old names (extract_keywords, find_similar_posts, …) are dropped by
/// migration 24; these are the current ones.
class DbRpc {
  const DbRpc._();
  static const String extractKeywords = 'nlp_extract_keywords';
  static const String keywordOverlapScore = 'nlp_keyword_overlap_score';
  static const String findSimilarPosts = 'search_similar_posts';
  static const String findSimilarStories = 'search_similar_stories';
  static const String upsertAuraPoints = 'gamification_upsert_aura';
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
  // end-to-end encrypted (migration 18)
  static const String sendE2ee = 'msg_send_e2ee';
  static const String editE2ee = 'msg_edit_e2ee';
}

/// End-to-end encryption keys, sender keys and PIN backup (migration 18).
class E2eeRpc {
  const E2eeRpc._();
  static const String registerDevice = 'e2ee_register_device';
  static const String setSignedPreKey = 'e2ee_set_signed_prekey';
  static const String uploadPreKeys = 'e2ee_upload_prekeys';
  static const String status = 'e2ee_status';
  static const String bundle = 'e2ee_get_bundle';
  static const String identities = 'e2ee_get_identities';
  static const String putSenderKeys = 'msg_put_sender_keys';
  static const String getSenderKeys = 'msg_get_sender_keys';
  static const String ackSenderKeys = 'msg_ack_sender_keys';
  static const String backupInfo = 'e2ee_backup_info';
  static const String backupBegin = 'e2ee_backup_begin';
  static const String backupPut = 'e2ee_backup_put';
  static const String backupRestore = 'e2ee_backup_restore';
  static const String backupDelete = 'e2ee_backup_delete';
  // migration 20: which conversations this account still belongs to, so the
  // phone can drop keys and cached text of chats it left or that were deleted
  static const String myConversationIds = 'msg_my_conversation_ids';
  // migration 23: governance key (every message also sealed to it)
  static const String governance = 'e2ee_governance';
}

/// OSINT analyst applications (migration 20).
class OsintRpc {
  const OsintRpc._();
  static const String apply = 'osint_apply';
  static const String myApplication = 'osint_get_my_application';
}

/// RPCs for filing reports and following their outcome (migration 05).
/// The moderator queue lives in the admin app (`features/admin`).
class ReportRpc {
  const ReportRpc._();
  static const String report = 'mod_report';
  static const String reportMessage = 'mod_report_message';
  static const String myReports = 'mod_get_my_reports';
}

/// RPCs every signed-in user calls about their own account.
class AccountRpc {
  const AccountRpc._();
  static const String myAccess = 'auth_get_my_access';
  static const String deleteSelf = 'account_delete_self';

  /// Exact phrase `account_delete_self` requires.
  static const String deleteConfirmation = 'DELETE MY ACCOUNT';
}

/// Follow graph RPCs (migration 11).
class FollowRpc {
  const FollowRpc._();
  static const String stats = 'follow_get_stats';
  static const String set = 'follow_set';
  static const String toggle = 'follow_toggle';
  static const String list = 'follow_get_list';
}

/// Comments & replies RPCs (migration 11).
class CommentRpc {
  const CommentRpc._();
  static const String create = 'comment_create';
  static const String edit = 'comment_edit';
  static const String delete = 'comment_delete';
  static const String toggleLike = 'comment_toggle_like';
  static const String forPost = 'comment_get_for_post';
  static const String replies = 'comment_get_replies';
}

/// Post reactions — one per user per post (migration 12).
class ReactionRpc {
  const ReactionRpc._();
  static const String forPost = 'reaction_get_for_post';
  static const String forPosts = 'reaction_get_for_posts';
  static const String toggle = 'reaction_toggle';
}

/// Analyst credibility, same model as the web `useCredibility` (migration 12).
class CredibilityRpc {
  const CredibilityRpc._();
  static const String get = 'credibility_get';
  static const String recalculateAll = 'credibility_recalculate_all';
}

/// Story publishing shared with the web composer (migration 12).
/// Leaning compass (migration 28). Only the signed-in user's own data.
class LeanRpc {
  const LeanRpc._();
  static const String me = 'lean_get_me';
  static const String setSettings = 'lean_set_settings';
  static const String reset = 'lean_reset';
}

/// Ranked feed and impressions (migration 28).
class FeedRpc {
  const FeedRpc._();
  static const String rank = 'feed_rank';
  static const String logImpressions = 'feed_log_impressions';
}

class StoryRpc {
  const StoryRpc._();
  static const String publish = 'story_publish';
  static const String setMeta = 'story_set_meta';
  static const String context = 'story_get_context';
}
