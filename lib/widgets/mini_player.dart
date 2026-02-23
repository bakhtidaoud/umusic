import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/player_controller.dart';
import '../utils/design_system.dart';
import '../screens/video_player_screen.dart';

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

      bool isDark = Theme.of(context).brightness == Brightness.dark;
      return GestureDetector(
        onTap: () => Get.to(
          () => VideoPlayerScreen(videoUrl: controller.currentVideoUrl.value),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          height: 70,
          decoration: UDesign.glass(
            context: context,
          ).copyWith(boxShadow: UDesign.softShadow(context)),
          child: UDesign.glassLayer(
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
                            color: isDark
                                ? UDesign.textHighDark
                                : UDesign.textHighLight,
                          ),
                        ),
                        Text(
                          controller.channelName.value,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: isDark
                                ? UDesign.textMedDark
                                : UDesign.textMedLight,
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
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? UDesign.textMedDark
                          : UDesign.textMedLight,
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
