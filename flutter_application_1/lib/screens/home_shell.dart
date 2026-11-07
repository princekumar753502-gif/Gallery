import 'package:flutter/material.dart';

import '../services/gallery_service.dart';
import '../state/gallery_controller.dart';
import '../state/theme_controller.dart';
import '../widgets/photo_grid.dart';
import '../widgets/state_views.dart';
import '../widgets/theme_menu_button.dart';
import 'albums_screen.dart';
import 'create_folder_screen.dart';

/// The main screen: handles permission states and the Photos / Albums tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final GalleryController _controller = GalleryController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Settings (or after taking new photos): reload quietly.
    if (state == AppLifecycleState.resumed) {
      _controller.refresh();
    }
  }

  /// The "+" button: opens the New folder screen, then reloads the albums.
  Future<void> _createFolder() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) =>
            CreateFolderScreen(path: _controller.allPhotos.path),
      ),
    );
    if (name == null || !mounted) return;

    await _controller.refresh();
    if (!mounted) return;
    setState(() => _tab = 1); // show the Albums tab with the new folder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$name" created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final ready = _controller.status == GalleryStatus.ready;
        final title = ready ? (_tab == 0 ? 'Photos' : 'Albums') : 'Gallery';

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              ThemeMenuButton(controller: widget.themeController),
              const SizedBox(width: 4),
            ],
          ),
          body: _buildBody(),
          floatingActionButton: ready
              ? FloatingActionButton(
                  tooltip: 'New folder',
                  onPressed: _createFolder,
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          bottomNavigationBar: ready
              ? NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.photo_library_outlined),
                      selectedIcon: Icon(Icons.photo_library_rounded),
                      label: 'Photos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.photo_album_outlined),
                      selectedIcon: Icon(Icons.photo_album_rounded),
                      label: 'Albums',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_controller.status) {
      case GalleryStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case GalleryStatus.permissionNeeded:
        return PermissionView(
          onAllow: _controller.retryPermission,
          onOpenSettings: GalleryService.openSettings,
        );

      case GalleryStatus.error:
        return EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: _controller.errorMessage ?? 'Please try again.',
          actionLabel: 'Try again',
          onAction: _controller.retryPermission,
        );

      case GalleryStatus.ready:
        return IndexedStack(
          index: _tab,
          children: [
            _PhotosTab(controller: _controller),
            AlbumsScreen(controller: _controller),
          ],
        );
    }
  }
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.controller});

  final GalleryController controller;

  Future<void> _manageSelection() async {
    await GalleryService.pickMoreLimited();
    await controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (controller.access == AccessLevel.limited)
          _LimitedBanner(onManage: _manageSelection),
        Expanded(
          child: PhotoGrid(
            source: controller.allPhotos,
            onRefresh: controller.refresh,
          ),
        ),
      ],
    );
  }
}

/// Android 14+: shown when the user only shared some photos with the app.
class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Showing only the photos and videos you selected.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onManage, child: const Text('Manage')),
        ],
      ),
    );
  }
}
