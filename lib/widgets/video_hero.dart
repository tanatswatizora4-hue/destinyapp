import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoHero extends StatefulWidget {
  const VideoHero({super.key});

  @override
  State<VideoHero> createState() => _VideoHeroState();
}

class _VideoHeroState extends State<VideoHero> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isLoading = true;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.asset('assets/videos/main_video.mp4');
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        showControls: false,
        showControlsOnInitialize: false,
        aspectRatio: 16 / 9,
        autoInitialize: true,
      );

      await _videoPlayerController.setVolume(0.0);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error initializing video player: $e");
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_chewieController.videoPlayerController.value.hasError)
            const Center(child: Icon(Icons.error, color: Colors.white, size: 48))
          else
            Chewie(controller: _chewieController),

          // Mute/Unmute button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
              onPressed: _toggleMute,
              tooltip: _isMuted ? 'Unmute' : 'Mute',
            ),
          ),
        ],
      ),
    );
  }
}

