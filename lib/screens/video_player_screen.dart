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
    controller = Get.find<PlayerController>();
    // Use post frame callback to ensure we don't trigger rebuilds during the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.initPlayer(widget.videoUrl);
    });
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
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load video',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => controller.initPlayer(widget.videoUrl),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show loading if explicit loading OR if we don't have a controller yet
        if (controller.isLoading.value || controller.podController == null) {
          return const Center(
            child: CircularProgressIndicator(color: UDesign.primary),
          );
        }

        bool isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: Theme.of(context).scaffoldBackgroundColor,
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
                          color: isDark
                              ? UDesign.textHighDark
                              : UDesign.textHighLight,
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
                              color: isDark
                                  ? UDesign.textMedDark
                                  : UDesign.textMedLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAction(context, Icons.thumb_up_rounded, 'Like'),
                          _buildAction(context, Icons.share_rounded, 'Share'),
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
                              context,
                              Icons.download_rounded,
                              'Download',
                            ),
                          ),
                          _buildAction(
                            context,
                            Icons.playlist_add_rounded,
                            'Save',
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Divider(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      // Audio-only toggle
                      UDesign.glassLayer(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: UDesign.glass(context: context),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: controller.isBackgroundMode.value
                                    ? UDesign.primary.withOpacity(0.2)
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.headset_rounded,
                                color: controller.isBackgroundMode.value
                                    ? UDesign.primary
                                    : (isDark
                                          ? UDesign.textMedDark
                                          : UDesign.textMedLight),
                              ),
                            ),
                            title: Text(
                              'Background Audio',
                              style: GoogleFonts.outfit(
                                color: isDark
                                    ? UDesign.textHighDark
                                    : UDesign.textHighLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Play audio even when app is closed',
                              style: GoogleFonts.outfit(
                                color: isDark
                                    ? UDesign.textMedDark
                                    : UDesign.textMedLight,
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

  Widget _buildAction(BuildContext context, IconData icon, String label) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.black87,
            size: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
