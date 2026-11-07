import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// A list of photos from one album that loads page by page, so huge
/// libraries stay fast and use little memory.
class PagedAssets extends ChangeNotifier {
  PagedAssets({this.path, this.pageSize = 120});

  AssetPathEntity? path;
  final int pageSize;
  final List<AssetEntity> assets = <AssetEntity>[];

  bool hasMore = true;
  bool isLoading = false;

  int _nextPage = 0;
  int _generation = 0; // bumps on refresh so stale loads are ignored
  bool _disposed = false;

  /// Reloads from the first page. Set [path] first to switch albums; with a
  /// null [path] the list is simply cleared.
  Future<void> refresh() async {
    final current = path;
    final generation = ++_generation;

    if (current == null) {
      assets.clear();
      hasMore = false;
      isLoading = false;
      _nextPage = 0;
      _notify();
      return;
    }

    isLoading = true;
    _notify();
    try {
      final first = await current.getAssetListPaged(page: 0, size: pageSize);
      if (generation != _generation) return;
      assets
        ..clear()
        ..addAll(first);
      _nextPage = 1;
      hasMore = first.length >= pageSize;
    } catch (e) {
      debugPrint('PagedAssets.refresh failed: $e');
    } finally {
      if (generation == _generation) {
        isLoading = false;
        _notify();
      }
    }
  }

  /// Loads the next page, if there is one.
  Future<void> loadMore() async {
    final current = path;
    if (current == null || isLoading || !hasMore) return;

    final generation = _generation;
    isLoading = true;
    _notify();
    try {
      final next =
          await current.getAssetListPaged(page: _nextPage, size: pageSize);
      if (generation != _generation) return;
      assets.addAll(next);
      _nextPage++;
      hasMore = next.length >= pageSize;
    } catch (e) {
      debugPrint('PagedAssets.loadMore failed: $e');
      hasMore = false;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        _notify();
      }
    }
  }

  /// Removes a photo from the in-memory list (after it was deleted).
  void removeAsset(AssetEntity asset) {
    assets.removeWhere((a) => a.id == asset.id);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
