import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../screens/photo_viewer_screen.dart';
import '../state/paged_assets.dart';
import '../untils/format.dart' show formatDuration;
import 'state_views.dart';

/// A square thumbnail of a photo or video, with a soft placeholder and
/// fade-in. Videos get a small play icon and their length in the corner.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.asset,
    this.size = 300,
  });

  final AssetEntity asset;
  final int size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVideo = asset.type == AssetType.video;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetEntityImageProvider(
              asset,
              isOriginal: false,
              thumbnailSize: ThumbnailSize.square(size),
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isVideo)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatDuration(asset.videoDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

/// A scrolling grid of photos with pull-to-refresh and endless loading.
class PhotoGrid extends StatefulWidget {
  const PhotoGrid({
    super.key,
    required this.source,
    this.onRefresh,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'Photos and videos you take or save will show up here.',
  });

  final PagedAssets source;
  final Future<void> Function()? onRefresh;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 900) {
      widget.source.loadMore();
    }
  }

  Future<void> _refresh() {
    final callback = widget.onRefresh;
    if (callback != null) return callback();
    return widget.source.refresh();
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoViewerScreen(
            source: widget.source,
            initialIndex: index,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.source,
      builder: (context, _) {
        final assets = widget.source.assets;

        if (assets.isEmpty) {
          if (widget.source.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: EmptyState(
                        icon: Icons.photo_outlined,
                        title: widget.emptyTitle,
                        message: widget.emptyMessage,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }

        final width = MediaQuery.sizeOf(context).width;
        var columns = (width / 125).floor();
        if (columns < 3) columns = 3;
        if (columns > 8) columns = 8;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: GridView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return GestureDetector(
                key: ValueKey(asset.id),
                onTap: () => _openViewer(index),
                child: PhotoThumbnail(asset: asset),
              );
            },
          ),
        );
      },
    );
  }
}
