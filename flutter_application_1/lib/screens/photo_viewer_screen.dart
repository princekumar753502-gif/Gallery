import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/gallery_service.dart';
import '../state/paged_assets.dart';
import '../widgets/video_player_view.dart';
import '../widgets/zoomable_image.dart';
import '../untils/format.dart' show formatDuration;

String formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = -1;
  do {
    size /= 1024;
    unit++;
  } while (size >= 1024 && unit < units.length - 1);
  return '${size.toStringAsFixed(1)} ${units[unit]}';
}

/// Full-screen viewer: swipe between photos, pinch to zoom, tap to hide the
/// controls, see details, delete.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.source,
    required this.initialIndex,
  });

  final PagedAssets source;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _index;
  bool _chromeVisible = true;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  int _clampIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index > length - 1) return length - 1;
    return index;
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
    });
    final total = widget.source.assets.length;
    if (index >= total - 10) {
      widget.source.loadMore();
    }
  }

  Future<void> _showInfo(AssetEntity asset) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _InfoSheet(asset: asset),
    );
  }

  Future<void> _delete(AssetEntity asset) async {
    final noun = asset.type == AssetType.video ? 'video' : 'photo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $noun?'),
        content: Text('This $noun will be removed from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    bool deleted = false;
    try {
      deleted = await GalleryService.deleteAsset(asset);
    } catch (e) {
      debugPrint('Delete failed: $e');
    }
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The $noun was not deleted.')),
      );
      return;
    }

    widget.source.removeAsset(asset);
    if (widget.source.assets.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _zoomed = false;
      _index = _clampIndex(_index, widget.source.assets.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: widget.source,
          builder: (context, _) {
            final assets = widget.source.assets;
            if (assets.isEmpty) {
              return const SizedBox.shrink();
            }
            final current = assets[_clampIndex(_index, assets.length)];

            return Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  itemCount: assets.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final asset = assets[i];
                    if (asset.type == AssetType.video) {
                      return VideoPlayerView(
                        key: ValueKey(asset.id),
                        asset: asset,
                        onTap: _toggleChrome,
                        controlsVisible: _chromeVisible,
                        isActive: i == _index,
                      );
                    }
                    return ZoomableImage(
                      key: ValueKey(asset.id),
                      asset: asset,
                      onTap: _toggleChrome,
                      onZoomChanged: (zoomed) {
                        if (zoomed != _zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      },
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _FadingBar(
                    visible: _chromeVisible,
                    gradientBegin: Alignment.topCenter,
                    gradientEnd: Alignment.bottomCenter,
                    padding: EdgeInsets.fromLTRB(
                      4,
                      MediaQuery.paddingOf(context).top + 4,
                      12,
                      28,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatDate(current.createDateTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _FadingBar(
                    visible: _chromeVisible,
                    gradientBegin: Alignment.bottomCenter,
                    gradientEnd: Alignment.topCenter,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      MediaQuery.paddingOf(context).bottom + 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BarAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Details',
                          onPressed: () => _showInfo(current),
                        ),
                        _BarAction(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onPressed: () => _delete(current),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FadingBar extends StatelessWidget {
  const _FadingBar({
    required this.visible,
    required this.gradientBegin,
    required this.gradientEnd,
    required this.padding,
    required this.child,
  });

  final bool visible;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: gradientBegin,
              end: gradientEnd,
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoDetails {
  const _PhotoDetails({required this.name, required this.sizeBytes});

  final String name;
  final int? sizeBytes;
}

class _InfoSheet extends StatefulWidget {
  const _InfoSheet({required this.asset});

  final AssetEntity asset;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  late final Future<_PhotoDetails> _future = _load();

  Future<_PhotoDetails> _load() async {
    String name = 'Photo';
    int? size;
    try {
      name = await widget.asset.titleAsync;
    } catch (_) {}
    try {
      final file = await widget.asset.originFile;
      size = await file?.length();
    } catch (_) {}
    return _PhotoDetails(name: name, sizeBytes: size);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: FutureBuilder<_PhotoDetails>(
          future: _future,
          builder: (context, snapshot) {
            final details = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.image_outlined,
                  label: 'Name',
                  value: details?.name ?? 'Loading...',
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: formatDateTime(asset.createDateTime),
                ),
                if (asset.type == AssetType.video)
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: formatDuration(asset.videoDuration),
                  ),
                _InfoRow(
                  icon: Icons.aspect_ratio_rounded,
                  label: 'Resolution',
                  value: '${asset.orientatedWidth} × ${asset.orientatedHeight}',
                ),
                if (details?.sizeBytes != null)
                  _InfoRow(
                    icon: Icons.sd_storage_outlined,
                    label: 'Size',
                    value: formatBytes(details!.sizeBytes!),
                  ),
                if (asset.relativePath != null &&
                    asset.relativePath!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    label: 'Location',
                    value: asset.relativePath!,
                  ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
