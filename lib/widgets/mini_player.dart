import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/player_controller.dart';
import '../utils/design_system.dart';
import 'video_player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return Obx(() {
      if (!controller.showMiniPlayer.value ||
          controller.currentVideoUrl.isEmpty) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: () => Get.to(
          () => VideoPlayerScreen(videoUrl: controller.currentVideoUrl.value),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          height: 70,
          decoration: UDesign.glassDecoration(
            borderRadius: BorderRadius.circular(20),
            color: UDesign.surface.withOpacity(0.9),
          ).copyWith(boxShadow: UDesign.premiumShadows()),
          child: UDesign.glassMaterial(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: controller.thumbnailUrl.value,
                      width: 100,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title & Channel
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.videoTitle.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          controller.channelName.value,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Controls
                  IconButton(
                    icon: Icon(
                      controller.isPlaying.value
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: UDesign.primary,
                    ),
                    onPressed: () => controller.togglePlayPause(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                    ),
                    onPressed: () => controller.stopAndDismiss(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().slideY(
        begin: 1,
        end: 0,
        duration: 400.ms,
        curve: Curves.easeOutCubic,
      );
    });
  }
}
