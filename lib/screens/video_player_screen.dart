import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/player_controller.dart';
import '../controllers/download_controller.dart';
import '../utils/design_system.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final PlayerController controller;

  @override
  void initState() {
    super.initState();
    // Using find because it should be initialized globally or at least persist
    controller = Get.find<PlayerController>();
    controller.initPlayer(widget.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => controller.minimize(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: UDesign.primary),
          );
        }

        if (controller.podController == null) {
          return const Center(
            child: Text(
              'Error loading player',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PodVideoPlayer(
                controller: controller.podController!,
                podProgressBarConfig: const PodProgressBarConfig(
                  padding: EdgeInsets.zero,
                  playingBarColor: UDesign.primary,
                  circleHandlerColor: UDesign.primary,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: UDesign.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.videoTitle.value,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: UDesign.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              controller.channelName.value,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: UDesign.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'YouTube',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAction(Icons.thumb_up_rounded, 'Like'),
                          _buildAction(Icons.share_rounded, 'Share'),
                          GestureDetector(
                            onTap: () {
                              final downloadController =
                                  Get.find<DownloadController>();
                              downloadController.downloadFile(
                                widget.videoUrl,
                                fileName: "${controller.videoTitle.value}.mp4",
                                isYoutube: true,
                              );
                              Get.snackbar(
                                'Download Started',
                                'Added ${controller.videoTitle.value} to queue',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            },
                            child: _buildAction(
                              Icons.download_rounded,
                              'Download',
                            ),
                          ),
                          _buildAction(Icons.playlist_add_rounded, 'Save'),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Divider(color: Colors.white10),
                      ),
                      // Audio-only toggle
                      UDesign.glassMaterial(
                        borderRadius: UDesign.brMedium,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: UDesign.brMedium,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: controller.isBackgroundMode.value
                                    ? UDesign.primary.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.headset_rounded,
                                color: controller.isBackgroundMode.value
                                    ? UDesign.primary
                                    : Colors.white60,
                              ),
                            ),
                            title: Text(
                              'Background Audio',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Play audio even when app is closed',
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Switch(
                              value: controller.isBackgroundMode.value,
                              activeColor: UDesign.primary,
                              onChanged: (v) =>
                                  controller.toggleBackgroundMode(v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
