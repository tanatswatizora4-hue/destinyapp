import 'package:chewie/chewie.dart';
import 'package:destiny/widgets/travel_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-bleed cinematic hero video used on Home.
/// Overlay content (headline, search) is composed by the parent.
///
/// Owned-media [posterRef] (Destiny storage reference) is always painted as the
/// base layer so loading / video failure stay full-bleed without layout shift.
class VideoHero extends StatefulWidget {
  final double height;

  /// Destiny media reference for the hero poster / fallback still.
  /// Defaults to `destiny-media/home/hero/main.webp`.
  final String posterRef;

  const VideoHero({
    super.key,
    this.height = 420,
    this.posterRef = 'destiny-media/home/hero/main.webp',
  });

  @override
  State<VideoHero> createState() => _VideoHeroState();
}

class _VideoHeroState extends State<VideoHero> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final controller =
          VideoPlayerController.asset('assets/videos/main_video.mp4');
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: true,
        showControls: false,
        showControlsOnInitialize: false,
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        autoInitialize: true,
      );
      await controller.setVolume(0.0);

      if (!mounted) {
        controller.dispose();
        chewie.dispose();
        return;
      }

      setState(() {
        _videoPlayerController = controller;
        _chewieController = chewie;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    final controller = _videoPlayerController;
    if (controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoReady =
        !_isLoading && !_hasError && _chewieController != null;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0A2540)),
          // Owned hero still — poster while video loads, and fallback if video fails.
          TravelNetworkImage(
            imageUrl: widget.posterRef,
            fit: BoxFit.cover,
            width: double.infinity,
            height: widget.height,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          else if (videoReady)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _videoPlayerController!.value.size.width,
                height: _videoPlayerController!.value.size.height,
                child: Chewie(controller: _chewieController!),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: videoReady ? _toggleMute : null,
                tooltip: _isMuted ? 'Unmute' : 'Mute',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
