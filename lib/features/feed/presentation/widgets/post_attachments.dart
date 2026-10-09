import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/post_extras.dart';

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Photos, plus images that were attached as a file (posted before the
/// composer started treating picked images as photos).
bool attachmentShowsAsImage(PostAttachment a) {
  if (a.kind == AttachmentKind.image) return true;
  if (a.kind != AttachmentKind.file) return false;
  if (a.mimeType?.startsWith('image/') ?? false) return true;
  final name = (a.fileName ?? a.url).toLowerCase().split('?').first;
  return RegExp(r'\.(jpe?g|png|webp|gif|heic|heif)$').hasMatch(name);
}

/// A post's attachments: photos in a grid, then videos, audio and files in
/// posting order.
class PostAttachments extends StatelessWidget {
  const PostAttachments({required this.attachments, super.key});

  final List<PostAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where(attachmentShowsAsImage).toList();
    final others =
        attachments.where((a) => !attachmentShowsAsImage(a)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.isNotEmpty) _ImageGrid(images: images),
        for (final a in others) ...[
          if (images.isNotEmpty || a != others.first) const SizedBox(height: 8),
          switch (a.kind) {
            AttachmentKind.video => _VideoTile(attachment: a),
            AttachmentKind.audio => _AudioTile(attachment: a),
            _ => _FileTile(attachment: a),
          },
        ],
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(15), child: child),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: palette.surface2),
      errorWidget: (_, __, ___) => Container(
        color: palette.surface2,
        child: Icon(Icons.broken_image_outlined, color: palette.muted),
      ),
    );
  }
}

/// One photo at 16:10 like a single-photo post; two side by side; three or
/// four in a 2×2 grid.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<PostAttachment> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return _Frame(
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _NetworkImage(url: images.first.url),
        ),
      );
    }
    return _Frame(
      child: AspectRatio(
        aspectRatio: images.length == 2 ? 2 : 1,
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final image in images)
              Semantics(
                image: true,
                label: image.fileName ?? 'Photo',
                child: _NetworkImage(url: image.url),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.attachment});

  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final thumb = attachment.thumbnailUrl;
    return Semantics(
      button: true,
      label: 'Play video',
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _VideoDialog(url: attachment.url),
        ),
        child: _Frame(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null)
                  _NetworkImage(url: thumb)
                else
                  const ColoredBox(color: Colors.black),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 34, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url});

  final String url;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }, onError: (Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_failed)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text("Couldn't play this video.",
                  style: TextStyle(color: Colors.white)),
            )
          else if (!ready)
            const Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play()),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays in place. The player is only created on the first tap so a feed
/// full of audio posts doesn't open a connection per post.
class _AudioTile extends StatefulWidget {
  const _AudioTile({required this.attachment});

  final PostAttachment attachment;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  VideoPlayerController? _controller;
  bool _loading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    var controller = _controller;
    if (controller == null) {
      controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.attachment.url));
      setState(() {
        _controller = controller;
        _loading = true;
      });
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      try {
        await controller.initialize();
      } on Object {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
    } else {
      if (value.position >= value.duration)
        await controller.seekTo(Duration.zero);
      await controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = _controller?.value;
    final playing = value?.isPlaying ?? false;
    final progress = (value != null && value.duration.inMilliseconds > 0)
        ? value.position.inMilliseconds / value.duration.inMilliseconds
        : 0.0;

    return _Frame(
      child: Container(
        color: palette.surface2,
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded),
              iconSize: 34,
              color: palette.accent,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.attachment.fileName ?? 'Audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 3,
                      color: palette.accent,
                      backgroundColor: palette.border,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.attachment});

  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = formatBytes(attachment.sizeBytes);
    return _Frame(
      child: Material(
        color: palette.surface2,
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(attachment.url),
              mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: palette.verified),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(attachment.fileName ?? 'File',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                if (size.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(size,
                      style: TextStyle(fontSize: 12, color: palette.muted)),
                ],
                const SizedBox(width: 6),
                Icon(Icons.open_in_new_rounded, size: 16, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
