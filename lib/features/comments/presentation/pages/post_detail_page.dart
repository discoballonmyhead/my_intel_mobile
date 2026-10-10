import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../../feed/presentation/widgets/edit_post_sheet.dart';
import '../../../feed/presentation/widgets/post_actions_sheet.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/post_edit_history_sheet.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/mod_actions.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../domain/entities/comment.dart';
import '../cubits/post_detail_cubit.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_tile.dart';

/// Optional `extra` for the /post/:postId route.
class PostDetailArgs {
  const PostDetailArgs({this.focusComposer = false});

  /// Opened from the comment button → keyboard up straight away.
  final bool focusComposer;
}

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({this.args = const PostDetailArgs(), super.key});

  final PostDetailArgs args;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<PostDetailCubit>().loadMore();
      }
    });
    if (widget.args.focusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isStaff => context.read<AccessCubit>().state.isStaff;

  Future<void> _submit() async {
    final ok = await context.read<PostDetailCubit>().submit(_controller.text);
    if (ok && mounted) {
      _controller.clear();
      _focus.unfocus();
    }
  }

  void _reply(Comment comment) {
    _controller.clear();
    context.read<PostDetailCubit>().startReply(comment);
    _focus.requestFocus();
  }

  Future<void> _commentActions(Comment comment, Post post) async {
    final cubit = context.read<PostDetailCubit>();
    final myId = cubit.state.myUserId;
    final isStaff = _isStaff;
    final mine = comment.isMine(myId);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!comment.isGone)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () => Navigator.of(context).pop('reply'),
              ),
            if ((comment.body ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            if (comment.canEdit(myId))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            if (comment.canDelete(myId,
                postAuthorId: post.authorId, isStaff: isStaff))
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: context.palette.accent2),
                title: Text(mine ? 'Delete' : 'Delete from my post'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            if (!mine && comment.authorId != null && !comment.isGone)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: context.palette.warn),
                title: const Text('Report comment'),
                onTap: () => Navigator.of(context).pop('report'),
              ),
            if (isStaff && !mine && !comment.isRemoved)
              ListTile(
                leading: Icon(Icons.gavel_outlined,
                    color: context.palette.accent2),
                title: const Text('Remove (moderator)'),
                onTap: () => Navigator.of(context).pop('mod_remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'reply':
        _reply(comment);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: comment.body ?? ''));
        if (mounted) AppDialogs.snack(context, 'Copied.');
      case 'edit':
        _controller.text = comment.body ?? '';
        cubit.startEdit(comment);
        _focus.requestFocus();
      case 'delete':
        {
          final ok = await AppDialogs.confirm(
            context,
            title: 'Delete comment?',
            message: comment.isRoot && comment.replyCount > 0
                ? 'Replies stay visible; the comment shows as deleted.'
                : 'This cannot be undone.',
            confirmLabel: 'DELETE',
            destructive: true,
          );
          if (ok) await cubit.deleteComment(comment);
        }
      case 'report':
        await ReportSheet.show(
          context,
          targetType: ReportTargetType.comment,
          targetId: '${comment.id}',
        );
      case 'mod_remove':
        {
          final removed = await ModActions.removeComment(context, comment.id);
          if (removed) cubit.markRemoved(comment);
        }
    }
  }

  Future<void> _postActions(Post post) async {
    final cubit = context.read<PostDetailCubit>();
    final feed = context.read<FeedProvider>();
    final action = await PostActionsSheet.show(
      context,
      post: post,
      myUserId: cubit.state.myUserId,
      isStaff: _isStaff,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case PostAction.edit:
        {
          final body = await EditPostSheet.show(context, post);
          if (body == null || !mounted) return;
          final ok = await feed.editPost(post, body);
          if (!mounted) return;
          if (ok) {
            await cubit.refresh();
          } else {
            AppDialogs.snack(context, feed.failure?.message ?? 'Edit failed.');
          }
        }
      case PostAction.delete:
        {
          final confirmed = await AppDialogs.confirm(
            context,
            title: 'Delete post?',
            message: 'It disappears from every feed. This cannot be undone.',
            confirmLabel: 'DELETE',
            destructive: true,
          );
          if (!confirmed || !mounted) return;
          final ok = await feed.deletePost(post);
          if (!mounted) return;
          if (ok) {
            context.pop();
          } else {
            AppDialogs.snack(context, feed.failure?.message ?? 'Delete failed.');
          }
        }
      case PostAction.history:
        await PostEditHistorySheet.show(context, post);
      case PostAction.report:
        await ReportSheet.show(
          context,
          targetType: ReportTargetType.post,
          targetId: '${post.id}',
        );
      case PostAction.modRemove:
        {
          final removed = await ModActions.removePost(context, post.id);
          if (removed && mounted) {
            feed.removeLocally(post.id);
            context.pop();
          }
        }
      case PostAction.viewAuthor:
        {
          final username = post.author?.username;
          if (username != null) context.push(AppRoutes.channelFor(username));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Keep the feed card (likes, comment count…) in step with this screen.
        BlocListener<PostDetailCubit, PostDetailState>(
          listenWhen: (a, b) => b.post != null && a.post != b.post,
          listener: (context, state) =>
              context.read<FeedProvider>().syncPost(state.post!),
        ),
        BlocListener<PostDetailCubit, PostDetailState>(
          listenWhen: (a, b) =>
              b.actionFailure != null && a.actionFailure != b.actionFailure,
          listener: (context, state) {
            AppDialogs.snack(context, state.actionFailure!.message);
            context.read<PostDetailCubit>().clearActionFailure();
          },
        ),
      ],
      child: BlocBuilder<PostDetailCubit, PostDetailState>(
        builder: (context, state) {
          final cubit = context.read<PostDetailCubit>();
          final post = state.post;

          return Scaffold(
            appBar: AppBar(title: const Text('POST')),
            body: switch (state.status) {
              PostDetailStatus.loading => const AppLoader(),
              PostDetailStatus.error => AppErrorView(
                  failure: state.failure ?? const NotFoundFailure(),
                  onRetry: cubit.load,
                ),
              PostDetailStatus.ready => Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: cubit.refresh,
                        child: ContentColumn(
                          padded: false,
                          child: _Thread(
                            state: state,
                            scroll: _scroll,
                            onReply: _reply,
                            onMore: (c) => _commentActions(c, post!),
                            onPostMore: () => _postActions(post!),
                            onCommentButton: () => _focus.requestFocus(),
                          ),
                        ),
                      ),
                    ),
                    CommentComposer(
                      controller: _controller,
                      focusNode: _focus,
                      onSubmit: _submit,
                      isSending: state.isSending,
                      replyTo: state.replyTo,
                      editing: state.editing,
                      onCancel: () {
                        _controller.clear();
                        if (state.editing != null) {
                          cubit.cancelEdit();
                        } else {
                          cubit.cancelReply();
                        }
                      },
                    ),
                  ],
                ),
            },
          );
        },
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.state,
    required this.scroll,
    required this.onReply,
    required this.onMore,
    required this.onPostMore,
    required this.onCommentButton,
  });

  final PostDetailState state;
  final ScrollController scroll;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onMore;
  final VoidCallback onPostMore;
  final VoidCallback onCommentButton;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PostDetailCubit>();
    final palette = context.palette;
    final post = state.post!;
    void openChannel(String username) =>
        context.push(AppRoutes.channelFor(username));

    final children = <Widget>[
      PostCard(
        item: OriginalPost(post),
        onLike: cubit.togglePostLike,
        onSave: cubit.togglePostSave,
        onRepost: cubit.togglePostRepost,
        onComment: onCommentButton,
        onMore: onPostMore,
        onAuthorTap: openChannel,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
        child: Text(
          '${state.commentCount} COMMENT${state.commentCount == 1 ? '' : 'S'}',
          style: AppTypography.mono(
              size: 10, color: palette.muted, letterSpacing: 1.5),
        ),
      ),
      if (state.comments.isEmpty)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: AppEmptyView(
            message: 'Be the first to comment',
            icon: Icons.mode_comment_outlined,
          ),
        ),
    ];

    for (final root in state.comments) {
      children.add(CommentTile(
        key: ValueKey('c-${root.id}'),
        comment: root,
        isPostAuthor: root.authorId != null && root.authorId == post.authorId,
        onReply: () => onReply(root),
        onLike: () => cubit.toggleCommentLike(root),
        onMore: () => onMore(root),
        onAuthorTap: openChannel,
      ));

      final expanded = state.expanded.contains(root.id);
      if (expanded) {
        for (final reply in state.repliesOf(root.id)) {
          children.add(CommentTile(
            key: ValueKey('c-${reply.id}'),
            comment: reply,
            isReply: true,
            isPostAuthor:
                reply.authorId != null && reply.authorId == post.authorId,
            onReply: () => onReply(reply),
            onLike: () => cubit.toggleCommentLike(reply),
            onMore: () => onMore(reply),
            onAuthorTap: openChannel,
          ));
        }
      }

      if (root.replyCount > 0) {
        final loading = state.loadingReplies.contains(root.id);
        final remaining = root.replyCount - state.repliesOf(root.id).length;
        children.add(Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxxl),
          child: Align(
            alignment: Alignment.centerLeft,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: expanded && remaining > 0
                        ? () => cubit.loadMoreReplies(root)
                        : () => cubit.toggleThread(root),
                    child: Text(
                      !expanded
                          ? '— VIEW ${root.replyCount} '
                              'REPL${root.replyCount == 1 ? 'Y' : 'IES'}'
                          : remaining > 0
                              ? '— VIEW $remaining MORE'
                              : '— HIDE REPLIES',
                      style: AppTypography.mono(size: 9, color: palette.muted),
                    ),
                  ),
          ),
        ));
      }
      children.add(Divider(height: 1, color: palette.border));
    }

    if (state.isLoadingMore) {
      children.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: AppLoader(),
      ));
    }
    children.add(const SizedBox(height: AppSpacing.xxl));

    return ListView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}
