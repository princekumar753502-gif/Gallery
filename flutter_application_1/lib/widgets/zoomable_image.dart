
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// Full-screen photo with pinch-to-zoom, panning and double-tap zoom.
class ZoomableImage extends StatefulWidget {
  const ZoomableImage({
    super.key,
    required this.asset,
    required this.onTap,
    required this.onZoomChanged,
  });

  final AssetEntity asset;
  final VoidCallback onTap;

  /// Called with true when the photo is zoomed in (so the page swipe can
  /// be disabled and the image can be panned instead).
  final ValueChanged<bool> onZoomChanged;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  final TransformationController _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.02;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// A size that keeps the photo's aspect ratio and caps the longest side
  /// at 2048 px, which is sharp when zoomed but light on memory.
  ThumbnailSize _viewerSize() {
    final w = widget.asset.orientatedWidth;
    final h = widget.asset.orientatedHeight;
    if (w <= 0 || h <= 0) return const ThumbnailSize.square(1600);

    final longest = w > h ? w : h;
    final scale = longest > 2048 ? 2048 / longest : 1.0;
    return ThumbnailSize((w * scale).round(), (h * scale).round());
  }

  void _onDoubleTap() {
    if (_isZoomed) {
      _transform.value = Matrix4.identity();
    } else {
      const scale = 2.5;
      final p = _doubleTapPosition;
      _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(-p.dx * (scale - 1), -p.dy * (scale - 1), 0);
    }
    widget.onZoomChanged(_isZoomed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
        child: Image(
          image: AssetEntityImageProvider(
            widget.asset,
            isOriginal: false,
            thumbnailSize: _viewerSize(),
          ),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}
