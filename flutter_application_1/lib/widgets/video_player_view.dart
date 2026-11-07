import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';

import '../untils/format.dart' show formatDuration;

/// Plays one video from the device inside the full-screen viewer.
///
/// Tap the big button to play / pause, tap anywhere else to hide or show the
/// controls, drag the slider to seek.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.asset,
    required this.onTap,
    required this.controlsVisible,
    required this.isActive,
  });

  final AssetEntity asset;

  /// Tap on the video (not on the buttons): show / hide the viewer controls.
  final VoidCallback onTap;

  /// Whether the viewer's top and bottom bars are visible.
  final bool controlsVisible;

  /// False when the user swiped to another page - the video pauses.
  final bool isActive;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final file = await widget.asset.file ?? await widget.asset.originFile;
      if (file == null) throw StateError('Video file not available');

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoChanged);
      setState(() => _video = controller);
    } catch (e) {
      debugPrint('Video load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onVideoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _video?.pause();
    }
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoChanged);
    _video?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final video = _video;
    if (video == null) return;

    if (video.value.isPlaying) {
      await video.pause();
      return;
    }
    final finished = video.value.position >= video.value.duration;
    if (finished) await video.seekTo(Duration.zero);
    await video.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 56),
            SizedBox(height: 12),
            Text(
              'This video cannot be played.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final video = _video;
    if (video == null) {
      // Still opening: show the thumbnail and a spinner.
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetEntityImageProvider(
              widget.asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(800),
            ),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    final value = video.value;
    final playing = value.isPlaying;
    final showButton = !playing || widget.controlsVisible;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
              child: VideoPlayer(video),
            ),
          ),
          // Big play / pause button.
          Center(
            child: IgnorePointer(
              ignoring: !showButton,
              child: AnimatedOpacity(
                opacity: showButton ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    iconSize: 48,
                    padding: const EdgeInsets.all(14),
                    color: Colors.white,
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: _togglePlay,
                    icon: Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Seek bar, placed above the viewer's Details / Delete bar.
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 104,
            child: IgnorePointer(
              ignoring: !widget.controlsVisible,
              child: AnimatedOpacity(
                opacity: widget.controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: _SeekBar(video: video),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.video});

  final VideoPlayerController video;

  @override
  Widget build(BuildContext context) {
    final value = video.value;
    final totalMs = math.max(value.duration.inMilliseconds, 1);
    final posMs = value.position.inMilliseconds.clamp(0, totalMs);

    const style = TextStyle(color: Colors.white, fontSize: 12);

    return Row(
      children: [
        Text(formatDuration(value.position), style: style),
        Expanded(
          child: Slider(
            value: posMs.toDouble(),
            min: 0,
            max: totalMs.toDouble(),
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
            onChanged: (v) => video.seekTo(Duration(milliseconds: v.round())),
          ),
        ),
        Text(formatDuration(value.duration), style: style),
      ],
    );
  }
}
