import 'package:photo_manager/photo_manager.dart';

/// How much of the photo library the user has allowed us to see.
enum AccessLevel {
  /// Not allowed (denied, or not asked yet).
  none,

  /// Android 14+ "Select photos" - we only see photos the user picked.
  limited,

  /// Full access to all photos.
  full,
}

/// An album (folder) of photos and videos, such as "Camera" or "Screenshots".
class AlbumInfo {
  const AlbumInfo({required this.path, required this.count});

  final AssetPathEntity path;
  final int count;

  String get name => path.isAll ? 'All photos' : path.name;
}

/// Thin wrapper around the `photo_manager` plugin so the rest of the app
/// never talks to the plugin directly.
class GalleryService {
  GalleryService._();

  // Newest first.
  static final FilterOptionGroup _filter = FilterOptionGroup(
    orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  /// Photos AND videos (RequestType.image alone hides every video).
  static const RequestType _type = RequestType.common;

  /// Shows the system permission dialog if needed.
  static Future<AccessLevel> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return _toAccessLevel(state);
  }

  /// Reads the current permission WITHOUT showing a dialog.
  static Future<AccessLevel> checkAccess() async {
    final state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(),
    );
    return _toAccessLevel(state);
  }

  static AccessLevel _toAccessLevel(PermissionState state) {
    if (state == PermissionState.limited) return AccessLevel.limited;
    if (state.hasAccess) return AccessLevel.full;
    return AccessLevel.none;
  }

  /// Lists all albums that contain at least one photo or video.
  /// The "All photos" (Recent) album comes first.
  static Future<List<AlbumInfo>> loadAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: _type,
      filterOption: _filter,
    );

    final albums = <AlbumInfo>[];
    for (final path in paths) {
      final count = await path.assetCountAsync;
      if (count > 0) {
        albums.add(AlbumInfo(path: path, count: count));
      }
    }

    albums.sort((a, b) {
      if (a.path.isAll != b.path.isAll) return a.path.isAll ? -1 : 1;
      return b.count.compareTo(a.count);
    });
    return albums;
  }

  /// Opens the app's page in Android Settings.
  static Future<void> openSettings() => PhotoManager.openSetting();

  /// Android 14+: lets the user choose more photos to share with the app.
  static Future<void> pickMoreLimited() {
    return PhotoManager.presentLimited(type: _type);
  }

  /// Deletes a photo/video from the device. Android 11+ shows a system
  /// confirmation. Returns true when it was actually deleted.
  static Future<bool> deleteAsset(AssetEntity asset) async {
    final deletedIds = await PhotoManager.editor.deleteWithIds([asset.id]);
    return deletedIds.contains(asset.id);
  }

  // ---------------------------------------------------------------------
  // New folder
  // ---------------------------------------------------------------------

  /// Removes characters Android does not allow in a folder name.
  /// Returns an empty string when nothing usable is left.
  static String cleanFolderName(String input) {
    var name = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    while (name.startsWith('.')) {
      name = name.substring(1).trim();
    }
    return name;
  }

  /// Android cannot show an EMPTY folder in the gallery (MediaStore only lists
  /// folders that contain files), so a "new folder" is created by moving the
  /// chosen photos/videos into it. `DCIM/<name>` accepts both images and
  /// videos.
  ///
  /// Returns true when the files were moved.
  static Future<bool> moveToNewFolder({
    required List<AssetEntity> assets,
    required String folderName,
  }) async {
    final name = cleanFolderName(folderName);
    if (name.isEmpty || assets.isEmpty) return false;
    final target = 'DCIM/$name';

    // Android 11+: one system dialog for all files, files are really moved.
    try {
      return await PhotoManager.editor.android.moveAssetsToPath(
        entities: assets,
        targetPath: target,
      );
    } catch (_) {
      // Android 10 and older (or the call is unsupported): copy, then delete.
      return _copyThenDelete(assets, target);
    }
  }

  static Future<bool> _copyThenDelete(
    List<AssetEntity> assets,
    String target,
  ) async {
    final copiedIds = <String>[];
    for (final asset in assets) {
      final file = await asset.originFile;
      if (file == null) continue;

      String title;
      try {
        title = await asset.titleAsync;
      } catch (_) {
        title = file.uri.pathSegments.last;
      }

      if (asset.type == AssetType.video) {
        await PhotoManager.editor.saveVideo(
          file,
          title: title,
          relativePath: target,
        );
      } else {
        await PhotoManager.editor.saveImageWithPath(
          file.path,
          title: title,
          relativePath: target,
        );
      }
      copiedIds.add(asset.id);
    }

    if (copiedIds.isEmpty) return false;

    // Remove the originals so it behaves like a move.
    await PhotoManager.editor.deleteWithIds(copiedIds);
    return true;
  }
}
