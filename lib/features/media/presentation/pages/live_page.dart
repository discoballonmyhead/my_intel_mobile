import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/video.dart';
import '../providers/media_provider.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MediaProvider>();
      if (provider.streamStatus == MediaStatus.initial) provider.loadStreams();
    });
  }

  Future<void> _createStream() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a stream'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Stream title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (title == null || title.trim().isEmpty || !mounted) return;
    await context.read<MediaProvider>().createStream(title);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaProvider>();
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('LIVE')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createStream,
        icon: const Icon(Icons.videocam_outlined),
        label: const Text('GO LIVE'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadStreams,
        child: switch (provider.streamStatus) {
          MediaStatus.initial || MediaStatus.loading => const AppLoader(),
          MediaStatus.error => AppErrorView(
              failure: provider.failure ?? const UnexpectedFailure(),
              onRetry: provider.loadStreams,
            ),
          MediaStatus.ready when provider.streams.isEmpty => const AppEmptyView(
              message: 'Nobody is live right now',
              icon: Icons.podcasts_outlined,
            ),
          MediaStatus.ready => ContentColumn(
              padded: false,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: provider.streams.length,
                itemBuilder: (context, index) {
                  final stream = provider.streams[index];
                  return _StreamTile(
                    stream: stream,
                    isHost: stream.hostId != null && stream.hostId == myId,
                    onGoLive: () => provider.setStatus(stream, LiveStatus.live),
                    onEnd: () => provider.setStatus(stream, LiveStatus.ended),
                  );
                },
              ),
            ),
        },
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  const _StreamTile({
    required this.stream,
    required this.isHost,
    this.onGoLive,
    this.onEnd,
  });

  final LiveStream stream;
  final bool isHost;
  final VoidCallback? onGoLive;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stream.isLive ? palette.accent2 : palette.muted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stream.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '@${stream.host?.username ?? 'unknown'} · '
                  '${stream.isLive ? '${stream.viewerCount} watching' : 'scheduled'}',
                  style: AppTypography.mono(size: 9, color: palette.muted),
                ),
              ],
            ),
          ),
          if (isHost)
            stream.isLive
                ? TextButton(onPressed: onEnd, child: const Text('END'))
                : TextButton(onPressed: onGoLive, child: const Text('START')),
        ],
      ),
    );
  }
}
