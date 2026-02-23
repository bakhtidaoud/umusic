import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/design_system.dart';
import '../screens/video_player_screen.dart';
import 'download_quality_sheet.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final bool isHorizontal;
  final bool isShort;

  const VideoCard({
    super.key,
    required this.video,
    this.isHorizontal = false,
    this.isShort = false,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isShort) {
      return _buildShortCard(context);
    }
    return _buildRegularCard(context);
  }

  Widget _buildRegularCard(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () =>
            Get.to(() => VideoPlayerScreen(videoUrl: widget.video.url)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? (Matrix4.identity()
                  ..translate(0, -8, 0)
                  ..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: UDesign.primary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : UDesign.softShadow(context),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isHovered
                    ? UDesign.primary.withOpacity(0.5)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05)),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildThumbnail(context), _buildDetails(context)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortCard(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () =>
            Get.to(() => VideoPlayerScreen(videoUrl: widget.video.url)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 180,
          transform: _isHovered
              ? (Matrix4.identity()
                  ..translate(0, -4, 0)
                  ..scale(1.03))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : UDesign.softShadow(context),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CachedNetworkImage(
                  imageUrl: widget.video.thumbnails.highResUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.black12),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Shorts',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: widget.video.thumbnails.highResUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 180,
            color: Theme.of(context).colorScheme.surface,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 180,
            color: Theme.of(context).colorScheme.surface,
            child: const Icon(Icons.broken_image_rounded, size: 48),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: UDesign.glassLayer(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: Colors.black.withOpacity(0.6),
              child: Text(
                widget.video.duration?.toString().split('.').first ?? '--:--',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        if (_isHovered)
          Positioned.fill(
            child: Container(
              color: UDesign.primary.withOpacity(0.1),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ).animate().fadeIn(duration: const Duration(milliseconds: 200)),
          ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: UDesign.premiumGradient,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Text(
                widget.video.author[0].toUpperCase(),
                style: GoogleFonts.outfit(
                  color: UDesign.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    color: isDark
                        ? UDesign.textHighDark
                        : UDesign.textHighLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.video.author} • ${widget.video.engagement.viewCount} views',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showDownloadSheet(context),
            icon: Icon(
              Icons.download_for_offline_outlined,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            tooltip: 'Download',
          ),
        ],
      ),
    );
  }

  void _showDownloadSheet(BuildContext context) {
    Get.bottomSheet(
      DownloadQualitySheet(url: widget.video.url, title: widget.video.title),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
