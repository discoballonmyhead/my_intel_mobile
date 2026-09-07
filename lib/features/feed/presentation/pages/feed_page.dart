import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_provider.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../providers/feed_provider.dart';
import '../widgets/composer_sheet.dart';
import '../widgets/post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  void initState() {
    super.initState();
    // Deferred so the first frame paints before the network call starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FeedProvider>();
      if (provider.status == FeedStatus.initial) provider.load();
      provider.listenForNewPosts();
    });
  }

  Future<void> _openComposer() async {
    final params = await ComposerSheet.show(context);
    if (params == null || !mounted) return;

    final provider = context.read<FeedProvider>();
    final ok = await provider.createPost(params);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Posted.' : provider.failure?.message ?? 'Post failed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    final responsive = context.watch<ResponsiveProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GENERAL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: provider.posting ? null : _openComposer,
        child: provider.posting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.edit_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: switch (provider.status) {
          FeedStatus.initial || FeedStatus.loading => const AppLoader(label: 'Loading feed'),
          FeedStatus.error => AppErrorView(
              failure: provider.failure ?? const UnexpectedFailure(),
              onRetry: provider.load,
            ),
          FeedStatus.ready when provider.isEmpty => const AppEmptyView(
              message: 'Nothing here yet',
              icon: Icons.rss_feed_rounded,
            ),
          FeedStatus.ready => ContentColumn(
              padded: false,
              maxWidth: responsive.isExpanded ? 720 : 680,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
                itemCount: provider.items.length,
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return PostCard(
                    item: item,
                    onLike: () => provider.toggleLike(item.post),
                    onSave: () => provider.toggleSave(item.post),
                    onRepost: () => provider.toggleRepost(item.post),
                    onAuthorTap: (username) =>
                        context.push(AppRoutes.channelFor(username)),
                  );
                },
              ),
            ),
        },
      ),
    );
  }
}
