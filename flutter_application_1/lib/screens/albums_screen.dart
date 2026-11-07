import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../services/gallery_service.dart';
import '../state/gallery_controller.dart';
import '../state/paged_assets.dart';
import '../widgets/photo_grid.dart';
import '../widgets/state_views.dart';

/// The "Albums" tab: a grid of folders such as Camera and Screenshots.
class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key, required this.controller});

  final GalleryController controller;

  void _openAlbum(BuildContext context, AlbumInfo album) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => AlbumPhotosScreen(album: album),
          ),
        )
        // Photos may have been deleted inside the album, so refresh counts.
        .then((_) => controller.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final albums = controller.albums;

    if (albums.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_album_outlined,
        title: 'No albums yet',
        message: 'Albums appear here once there are photos or videos on your device.',
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.9,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return _AlbumCard(
            key: ValueKey('${album.path.id}-${album.count}'),
            album: album,
            onTap: () => _openAlbum(context, album),
          );
        },
      ),
    );
  }
}

class _AlbumCard extends StatefulWidget {
  const _AlbumCard({super.key, required this.album, required this.onTap});

  final AlbumInfo album;
  final VoidCallback onTap;

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  late final Future<List<AssetEntity>> _cover =
      widget.album.path.getAssetListRange(start: 0, end: 1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final album = widget.album;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<List<AssetEntity>>(
              future: _cover,
              builder: (context, snapshot) {
                final items = snapshot.data;
                if (items == null || items.isEmpty) {
                  return Center(
                    child: Icon(
                      Icons.photo_album_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                return Image(
                  image: AssetEntityImageProvider(
                    items.first,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(500),
                  ),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.count == 1 ? '1 item' : '${album.count} items',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
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

/// Photos of a single album.
class AlbumPhotosScreen extends StatefulWidget {
  const AlbumPhotosScreen({super.key, required this.album});

  final AlbumInfo album;

  @override
  State<AlbumPhotosScreen> createState() => _AlbumPhotosScreenState();
}

class _AlbumPhotosScreenState extends State<AlbumPhotosScreen> {
  late final PagedAssets _source = PagedAssets(path: widget.album.path);

  @override
  void initState() {
    super.initState();
    _source.refresh();
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.name)),
      body: PhotoGrid(
        source: _source,
        emptyTitle: 'This folder is empty',
        emptyMessage: 'There are no photos or videos in this folder.',
      ),
    );
  }
}
