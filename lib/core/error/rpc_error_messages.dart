/// Human-readable copy for the error keys raised by the SQL RPCs
/// (`raise exception 'account_restricted' ...`). Unknown keys fall through to
/// the raw message so nothing is silently swallowed.
class RpcErrorMessages {
  const RpcErrorMessages._();

  static const Map<String, String> _messages = {
    // auth / access
    'not_authenticated': 'Please sign in again.',
    'forbidden': 'You do not have permission to do that.',
    'account_restricted': 'Your account is restricted right now.',
    'super_admin_required': 'Only a super admin can do that.',
    'cannot_sanction_self': 'You cannot take action against yourself.',
    'cannot_sanction_equal_or_higher_role':
        'You cannot act on someone with an equal or higher role.',
    'cannot_delete_equal_or_higher_role':
        'You cannot delete someone with an equal or higher role.',
    'cannot_remove_last_super_admin': 'There must always be one super admin.',
    'cannot_delete_last_super_admin':
        'Hand over super admin to someone else before deleting this account.',
    'moderators_can_only_suspend_up_to_7_days':
        'Moderators can only suspend for up to 7 days.',
    'use_account_delete_self': 'Delete your own account from Settings.',
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
    'invalid_outcome': 'Invalid decision.',
    'invalid_status': 'Invalid status.',
    'invalid_role': 'Unknown role.',
    'role_not_held': 'The user does not have that role.',
    'user_is_not_osint': 'That user is not an OSINT analyst.',
    'user_not_banned': 'That user is not banned.',
    'use_msg_delete_conversation_for_direct':
        'Delete the conversation instead of leaving it.',
    'only_sender_can_delete_for_everyone':
        'Only the sender can delete a message for everyone.',
    'message_not_reported': 'Only reported messages can be moderated.',
    'post_removed_by_moderation': 'This post was removed by moderators.',
    'deleted_posts_cannot_be_restored': 'Deleted posts cannot be restored.',
    'moderation_fields_are_staff_only': 'Only moderators can change that.',
    'role_is_managed_by_admins': 'Roles are managed by admins.',
    // not found
    'post_not_found': 'That post no longer exists.',
    'message_not_found': 'That message no longer exists.',
    'target_not_found': 'That content no longer exists.',
    'user_not_found': 'That user no longer exists.',
    'application_not_found': 'That application no longer exists.',
    'sanction_not_found': 'That sanction no longer exists.',
    'not_a_member': 'You are not part of this conversation.',
    'recipient_unavailable': 'This person is no longer available.',
    // throttling
    'rate_limited': 'Slow down a little and try again.',
  };

  /// `application_not_pending: approved` → keeps the detail after the colon.
  static String describe(String raw) {
    final key = raw.split(':').first.trim();
    if (key == 'application_not_pending') {
      final detail = raw.contains(':') ? raw.split(':').last.trim() : '';
      return 'This application was already reviewed${detail.isEmpty ? '' : ' ($detail)'}.';
    }
    return _messages[key] ?? raw;
  }
}
