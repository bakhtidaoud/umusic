import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/design_system.dart';

class ShortsScreen extends StatefulWidget {
  final List<Video> initialShorts;
  final int startIndex;

  const ShortsScreen({
    super.key,
    required this.initialShorts,
    this.startIndex = 0,
  });

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.initialShorts.length,
        itemBuilder: (context, index) {
          return ShortVideoItem(
            video: widget.initialShorts[index],
            isActive: true,
          );
        },
      ),
    );
  }
}

class ShortVideoItem extends StatefulWidget {
  final Video video;
  final bool isActive;

  const ShortVideoItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends State<ShortVideoItem> {
  late PodPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller =
        PodPlayerController(
            playVideoFrom: PlayVideoFrom.youtube(widget.video.id.value),
            podPlayerConfig: const PodPlayerConfig(
              autoPlay: true,
              isLooping: true,
              videoQualityPriority: [360, 480],
            ),
          )
          ..initialise().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInitialized)
          Positioned.fill(
            child: PodVideoPlayer(
              controller: _controller,
              frameAspectRatio: 9 / 16,
              podProgressBarConfig: const PodProgressBarConfig(
                playingBarColor: UDesign.primary,
                circleHandlerColor: UDesign.primary,
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: UDesign.primary),
          ),

        // Gradient overlay for better text visibility
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Overlay for back button and info
        Positioned(
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Get.back(),
          ),
        ),

        // Bottom Info
        Positioned(
          bottom: 40,
          left: 20,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.video.author}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),

        // Right Actions
        Positioned(
          bottom: 100,
          right: 20,
          child: Column(
            children: [
              _buildSideAction(Icons.favorite_rounded, 'Like'),
              const SizedBox(height: 20),
              _buildSideAction(Icons.comment_rounded, 'Chat'),
              const SizedBox(height: 20),
              _buildSideAction(Icons.share_rounded, 'Share'),
              const SizedBox(height: 20),
              _buildSideAction(Icons.download_rounded, 'Get'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
