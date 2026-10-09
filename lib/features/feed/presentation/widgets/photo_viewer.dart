import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen photos on black: swipe sideways between them, pinch or
/// double-tap to zoom, swipe down or tap ✕ to close.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({required this.urls, this.initialIndex = 0, super.key});

  final List<String> urls;
  final int initialIndex;

  static Future<void> open(BuildContext context, List<String> urls,
      {int index = 0}) {
    return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => PhotoViewer(urls: urls, initialIndex: index),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _zoomed = <int>{};
  double _drag = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final count = widget.urls.length;
    final canDrag = !_zoomed.contains(_index);
    // Fades the black background as a photo is pulled down.
    final fade = (1 - (_drag.abs() / 300)).clamp(0.3, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, _drag),
            child: PageView.builder(
              controller: _pages,
              physics: canDrag
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _ZoomablePhoto(
                url: widget.urls[i],
                onZoomChanged: (zoomed) =>
                    setState(() => zoomed ? _zoomed.add(i) : _zoomed.remove(i)),
                onPull: (dy) => setState(() => _drag += dy),
                onPullEnd: (velocity) {
                  if (_drag.abs() > 120 || velocity.abs() > 900) {
                    _close();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
              ),
            ),
          ),
          SafeArea(
            child: Opacity(
              opacity: _drag == 0 ? 1 : 0,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  if (count > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text('${_index + 1} / $count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index ? Colors.white : Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.onZoomChanged,
    required this.onPull,
    required this.onPullEnd,
  });

  final String url;
  final ValueChanged<bool> onZoomChanged;

  /// Vertical movement while not zoomed, to pull the viewer closed.
  final ValueChanged<double> onPull;
  final ValueChanged<double> onPullEnd;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) {
        setState(() => _zoomed = zoomed);
        widget.onZoomChanged(zoomed);
      }
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    final p = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 4,
        // Panning only moves a zoomed photo; otherwise a vertical drag
        // pulls the viewer closed.
        panEnabled: _zoomed,
        onInteractionUpdate: (d) {
          if (!_zoomed && d.pointerCount == 1) {
            widget.onPull(d.focalPointDelta.dy);
          }
        },
        onInteractionEnd: (d) {
          if (!_zoomed) widget.onPullEnd(d.velocity.pixelsPerSecond.dy);
        },
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

/// A photo in a post at its own shape: tall photos stay tall (down to 3:4)
/// and wide ones stay wide (up to 1.91:1), so most can be seen without
/// opening them. 16:10 until the size is known.
class AdaptivePhoto extends StatefulWidget {
  const AdaptivePhoto({
    required this.url,
    required this.child,
    this.width,
    this.height,
    super.key,
  });

  final String url;
  final int? width;
  final int? height;
  final Widget child;

  static const double tallest = 3 / 4;
  static const double widest = 1.91;

  static double clampRatio(double ratio) => ratio.clamp(tallest, widest);

  @override
  State<AdaptivePhoto> createState() => _AdaptivePhotoState();
}

class _AdaptivePhotoState extends State<AdaptivePhoto> {
  double? _ratio;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    final ratio = info.image.width / info.image.height;
    if (mounted) setState(() => _ratio = AdaptivePhoto.clampRatio(ratio));
  }, onError: (_, __) {});

  @override
  void initState() {
    super.initState();
    final w = widget.width, h = widget.height;
    if (w != null && h != null && w > 0 && h > 0) {
      _ratio = AdaptivePhoto.clampRatio(w / h);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ratio == null && _stream == null) {
      _stream = CachedNetworkImageProvider(widget.url)
          .resolve(createLocalImageConfiguration(context))
        ..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AspectRatio(aspectRatio: _ratio ?? 16 / 10, child: widget.child);
}
