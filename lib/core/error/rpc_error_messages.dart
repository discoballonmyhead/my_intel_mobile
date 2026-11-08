/// Human-readable copy for the error keys raised by the SQL RPCs
/// (`raise exception 'account_restricted' ...`). Unknown keys fall through to
/// the raw message so nothing is silently swallowed.
class RpcErrorMessages {
  const RpcErrorMessages._();

  /// Copy registered by another app built from this code (the admin app adds
  /// its staff-only keys at start-up, see `features/admin`).
  static final Map<String, String> _extra = {};

  static void register(Map<String, String> messages) => _extra.addAll(messages);

  static const Map<String, String> _messages = {
    // auth / access
    'not_authenticated': 'Please sign in again.',
    'forbidden': 'You do not have permission to do that.',
    'account_restricted': 'Your account is restricted right now.',
    // validation
    'reason_required': 'A reason is required.',
    'empty_content': 'Write something first.',
    'content_too_long': 'That is too long.',
    'empty_message': 'Message is empty.',
    'attachments_must_be_array': 'Attachments are malformed.',
    'invalid_recipient': 'You cannot message that user.',
    'group_needs_members': 'Add at least one other person.',
    'group_too_large': 'Groups are limited to 255 members.',
    'invalid_reply_target': 'The message you are replying to is gone.',
    'edit_window_expired': 'Messages can only be edited for 15 minutes.',
    'message_deleted': 'That message was deleted.',
    'not_editable': 'That message cannot be edited.',
    'confirmation_mismatch': 'Type the confirmation phrase exactly.',
    'invalid_target_type': 'That cannot be reported.',
    'cannot_report_own_content': 'You cannot report your own content.',
    'use_msg_delete_conversation_for_direct':
        'Delete the conversation instead of leaving it.',
    'only_sender_can_delete_for_everyone':
        'Only the sender can delete a message for everyone.',
    'post_removed_by_moderation': 'This post was removed by moderators.',
    'role_is_managed_by_admins': 'Roles are managed by admins.',
    // posts: attachments and polls (social_create_post / poll_vote)
    'empty_post': 'Write something or add an attachment first.',
    'body_too_long': 'That post is too long.',
    'invalid_attachments': 'Attachments are malformed.',
    'too_many_attachments': 'A post can have up to 4 attachments.',
    'invalid_attachment_kind': 'That type of attachment is not supported.',
    'attachment_not_owned': 'One of the attachments could not be used.',
    'attachment_url_mismatch': 'One of the attachments could not be used.',
    'attachment_not_found':
        'An attachment did not finish uploading. Try again.',
    'attachment_too_large': 'One of the attachments is too large.',
    'attachment_type_mismatch':
        'One of the attachments is not the type it claims to be.',
    'poll_not_allowed_on_news': 'News posts cannot have a poll.',
    'poll_needs_2_to_4_options': 'A poll needs 2 to 4 options.',
    'poll_duration_out_of_range': 'Polls can run from 1 hour to 7 days.',
    'poll_closed': 'This poll has closed.',
    'already_voted': 'You have already voted on this poll.',
    'poll_option_not_found': 'That option no longer exists.',
    'poll_not_found': 'That poll no longer exists.',
    'blocked_content': 'This post contains blocked content.',
    // not found
    'post_not_found': 'That post no longer exists.',
    'message_not_found': 'That message no longer exists.',
    'target_not_found': 'That content no longer exists.',
    'user_not_found': 'That user no longer exists.',
    'not_a_member': 'You are not part of this conversation.',
    'recipient_unavailable': 'This person is no longer available.',
    'comment_not_found': 'That comment no longer exists.',
    'comment_removed_by_moderation': 'This comment was removed by moderators.',
    'cannot_follow_self': 'You cannot follow yourself.',
    'invalid_kind': 'Unknown list.',
    // badge requests (migration 15)
    'invalid_badge': 'Unknown badge.',
    'already_has_badge': 'You already have that badge.',
    // OSINT applications (migration 20)
    'already_osint': 'You are already an OSINT analyst.',
    'application_already_pending': 'Your application is already in review.',
    'channel_name_length': 'Channel name must be 2–80 characters.',
    'handle_length': 'Handle must be 2–60 characters.',
    'application_too_long': 'Your application is too long.',
    // reporting, live and articles (migrations 16–20)
    'reporter_badge_required':
        'You need the Reporter or OSINT badge to do that.',
    'title_length': 'The title must be 3–120 characters.',
    'already_live': 'You are already live. End that stream first.',
    'stream_not_found': 'That live stream no longer exists.',
    'article_not_found': 'That article no longer exists.',
    'article_too_short': 'The article is too short.',
    'article_needs_a_source': 'Add at least one source.',
    'too_many_sources': 'Too many sources.',
    'sources_must_be_array': 'Sources are malformed.',
    'invalid_source_kind': 'Unknown source type.',
    'source_url_must_be_https': 'Source links must start with https://',
    'source_post_not_found': 'A linked post no longer exists.',
    'source_story_not_found': 'A linked story no longer exists.',
    'story_not_found': 'That story no longer exists.',
    // messaging and encryption (migrations 18–20)
    'conversation_is_end_to_end_encrypted':
        'This chat is encrypted. Update the app to send messages here.',
    'device_not_registered': 'Secure messaging isn’t set up on this phone yet.',
    'envelope_required': 'The message could not be encrypted.',
    'franking_tag_required': 'The message could not be encrypted.',
    'invalid_prekeys': 'Encryption keys were malformed.',
    'too_many_prekeys': 'Too many encryption keys at once.',
    'invalid_items': 'Encryption keys were malformed.',
    'invalid_verifier': 'That PIN could not be checked.',
    'no_shared_conversation': 'You do not share a chat with that person.',
    'report_does_not_match_message':
        'That report could not be verified against the message.',
    // governance key (migration 23)
    'escrow_required': 'Update the app to keep sending messages.',
    'escrow_key_outdated': 'The safety key changed. Try sending again.',
    'escrow_malformed': 'The message could not be encrypted.',
    // throttling
    'rate_limited': 'Slow down a little and try again.',
  };

  /// The bare error key (`reapply_after: 2026-11-30` → `reapply_after`).
  static String keyOf(String raw) => raw.split(':').first.trim();

  /// `application_not_pending: approved` → keeps the detail after the colon.
  static String describe(String raw) {
    final key = raw.split(':').first.trim();
    if (key == 'reapply_after') {
      final date = raw.contains(':') ? raw.split(':').last.trim() : '';
      return 'You can apply again${date.isEmpty ? ' later' : ' from $date'}.';
    }
    if (key == 'application_not_pending') {
      final detail = raw.contains(':') ? raw.split(':').last.trim() : '';
      return 'This application was already reviewed${detail.isEmpty ? '' : ' ($detail)'}.';
    }
    return _messages[key] ?? _extra[key] ?? raw;
  }
}
