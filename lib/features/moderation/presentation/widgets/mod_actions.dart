import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../domain/usecases/report_usecases.dart';

/// One-tap staff actions reachable from anywhere content is shown (feed,
/// channels), outside the report queue. Server RPCs re-check staff rights.
class ModActions {
  const ModActions._();

  /// Asks for a reason, removes the post, returns true on success.
  static Future<bool> removePost(BuildContext context, int postId) async {
    final reason = await AppDialogs.reason(
      context,
      title: 'Remove post',
      hint: 'Reason (logged, shown to the author)',
      confirmLabel: 'REMOVE',
      destructive: true,
    );
    if (reason == null) return false;

    final result =
        await sl<ModRemovePost>()(ModContentParams(id: postId, reason: reason));
    if (!context.mounted) return result.isOk;
    AppDialogs.snack(
        context, result.failureOrNull?.message ?? 'Post removed.');
    return result.isOk;
  }

  /// Asks for a reason, removes the comment, returns true on success.
  static Future<bool> removeComment(BuildContext context, int commentId) async {
    final reason = await AppDialogs.reason(
      context,
      title: 'Remove comment',
      hint: 'Reason (logged, shown to the author)',
      confirmLabel: 'REMOVE',
      destructive: true,
    );
    if (reason == null) return false;

    final result = await sl<ModRemoveComment>()(
        ModContentParams(id: commentId, reason: reason));
    if (!context.mounted) return result.isOk;
    AppDialogs.snack(
        context, result.failureOrNull?.message ?? 'Comment removed.');
    return result.isOk;
  }
}
