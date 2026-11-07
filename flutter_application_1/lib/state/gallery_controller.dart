import 'package:flutter/foundation.dart';

import '../services/gallery_service.dart';
import 'paged_assets.dart';

enum GalleryStatus { loading, permissionNeeded, ready, error }

/// Owns the permission state, the album list and the main "Photos" list.
class GalleryController extends ChangeNotifier {
  GalleryStatus status = GalleryStatus.loading;
  AccessLevel access = AccessLevel.none;
  List<AlbumInfo> albums = const [];
  String? errorMessage;

  /// Everything, newest first (the Photos tab).
  final PagedAssets allPhotos = PagedAssets();

  bool _busy = false;
  bool _disposed = false;

  /// First start: asks for permission (shows the system dialog) and loads.
  Future<void> start() => _load(request: true);

  /// User tapped "Allow access" / "Try again".
  Future<void> retryPermission() => _load(request: true);

  /// Quietly reloads (pull-to-refresh, app resumed). Never shows a dialog.
  Future<void> refresh() => _load(request: false);

  Future<void> _load({required bool request}) async {
    if (_busy) return;
    _busy = true;

    try {
      if (request) {
        status = GalleryStatus.loading;
        _notify();
      }

      final level = request
          ? await GalleryService.requestAccess()
          : await GalleryService.checkAccess();
      access = level;

      if (level == AccessLevel.none) {
        albums = const [];
        allPhotos.path = null;
        await allPhotos.refresh(); // clears the list
        status = GalleryStatus.permissionNeeded;
        _notify();
        return;
      }

      final loaded = await GalleryService.loadAlbums();
      albums = loaded;

      AlbumInfo? main;
      for (final album in loaded) {
        if (album.path.isAll) {
          main = album;
          break;
        }
      }
      main ??= loaded.isNotEmpty ? loaded.first : null;

      allPhotos.path = main?.path;
      await allPhotos.refresh();
      errorMessage = null;
      status = GalleryStatus.ready;
      _notify();
    } catch (e) {
      debugPrint('GalleryController load failed: $e');
      // Keep showing existing photos if a quiet refresh fails.
      if (request || status != GalleryStatus.ready) {
        errorMessage = e.toString();
        status = GalleryStatus.error;
      }
      _notify();
    } finally {
      _busy = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    allPhotos.dispose();
    super.dispose();
  }
}
