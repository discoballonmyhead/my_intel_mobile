import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/video.dart';
import '../providers/media_provider.dart';

/// Full-bleed vertical reel feed — the one screen that is deliberately
/// edge-to-edge on every breakpoint rather than a centred column.
class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MediaProvider>();
      if (provider.videoStatus == MediaStatus.initial) provider.loadVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('REELS'),
      ),
      body: switch (provider.videoStatus) {
        MediaStatus.initial || MediaStatus.loading => const AppLoader(),
        MediaStatus.error => AppErrorView(
            failure: provider.failure ?? const UnexpectedFailure(),
            onRetry: provider.loadVideos,
          ),
        MediaStatus.ready when provider.videos.isEmpty => const AppEmptyView(
            message: 'No reels yet',
            icon: Icons.movie_outlined,
          ),
        MediaStatus.ready => PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: provider.videos.length,
            itemBuilder: (context, index) => _ReelTile(
              video: provider.videos[index],
              onLike: () => provider.toggleLike(provider.videos[index]),
            ),
          ),
      },
    );
  }
}

class _ReelTile extends StatelessWidget {
  const _ReelTile({required this.video, this.onLike});

  final Video video;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (video.thumbnailUrl != null)
          CachedNetworkImage(imageUrl: video.thumbnailUrl!, fit: BoxFit.cover)
        else
          ColoredBox(color: palette.surface2),

        // Scrim so the overlaid text stays legible over any frame.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: 72,
          bottom: AppSpacing.xxl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${video.author?.username ?? 'unknown'}',
                style: AppTypography.mono(size: 12, color: Colors.white),
              ),
              if (video.title != null && video.title!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  video.title!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xxl,
          child: Column(
            children: [
              IconButton(
                onPressed: onLike,
                icon: Icon(
                  video.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: video.likedByMe ? palette.accent2 : Colors.white,
                  size: 28,
                ),
              ),
              Text(
                '${video.likes}',
                style: AppTypography.mono(size: 11, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Icon(Icons.visibility_outlined, color: Colors.white, size: 22),
              Text(
                '${video.viewCount}',
                style: AppTypography.mono(size: 11, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
