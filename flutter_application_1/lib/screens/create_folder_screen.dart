import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/gallery_service.dart';
import '../state/paged_assets.dart';
import '../widgets/photo_grid.dart';
import '../widgets/state_views.dart';

/// "New folder": type a name, tick the photos / videos that should go into
/// it, then press Create. Pops with the folder name when it worked.
class CreateFolderScreen extends StatefulWidget {
  const CreateFolderScreen({super.key, required this.path});

  /// The album to pick from (normally "All photos").
  final AssetPathEntity? path;

  @override
  State<CreateFolderScreen> createState() => _CreateFolderScreenState();
}

class _CreateFolderScreenState extends State<CreateFolderScreen> {
  late final PagedAssets _source = PagedAssets(path: widget.path);
  final TextEditingController _name = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Keeps the order in which the user ticked the items.
  final Map<String, AssetEntity> _selected = <String, AssetEntity>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _source.refresh();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _source.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 900) {
      _source.loadMore();
    }
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (_selected.remove(asset.id) == null) {
        _selected[asset.id] = asset;
      }
    });
  }

  bool get _canCreate =>
      !_busy &&
      GalleryService.cleanFolderName(_name.text).isNotEmpty &&
      _selected.isNotEmpty;

  Future<void> _create() async {
    final name = GalleryService.cleanFolderName(_name.text);
    setState(() => _busy = true);

    bool ok = false;
    try {
      ok = await GalleryService.moveToNewFolder(
        assets: _selected.values.toList(),
        folderName: name,
      );
    } catch (e) {
      debugPrint('Create folder failed: $e');
    }
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(name);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The folder was not created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = _selected.length;

    return Scaffold(
      appBar: AppBar(title: const Text('New folder')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Folder name',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                count == 0
                    ? 'Tap the photos and videos to put in this folder.'
                    : '$count selected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          Expanded(child: _buildGrid(scheme)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _canCreate ? _create : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.create_new_folder_outlined),
            label: Text(count == 0 ? 'Create folder' : 'Create folder ($count)'),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme scheme) {
    return ListenableBuilder(
      listenable: _source,
      builder: (context, _) {
        final assets = _source.assets;

        if (assets.isEmpty) {
          if (_source.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return const EmptyState(
            icon: Icons.photo_outlined,
            title: 'Nothing to add',
            message: 'There are no photos or videos on this device yet.',
          );
        }

        final width = MediaQuery.sizeOf(context).width;
        var columns = (width / 110).floor();
        if (columns < 3) columns = 3;
        if (columns > 8) columns = 8;

        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final selected = _selected.containsKey(asset.id);

            return GestureDetector(
              key: ValueKey(asset.id),
              onTap: _busy ? null : () => _toggle(asset),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoThumbnail(asset: asset, size: 250),
                  if (selected)
                    ColoredBox(color: scheme.primary.withValues(alpha: 0.35)),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? scheme.primary : Colors.black26,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: scheme.onPrimary,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
