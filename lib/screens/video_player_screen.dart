import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/player_controller.dart';
import '../controllers/download_controller.dart';
import '../widgets/download_quality_sheet.dart';
import '../utils/design_system.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final PlayerController controller;
  bool _isDescriptionExpanded = false;

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PodVideoPlayer(
                    controller: controller.podController!,
                    podProgressBarConfig: const PodProgressBarConfig(
                      padding: EdgeInsets.zero,
                      playingBarColor: UDesign.primary,
                      circleHandlerColor: UDesign.primary,
                    ),
                  ),
                  _buildGestureOverlay(),
                ],
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
                          _buildAction(
                            context,
                            controller.isLiked.value
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            'Like',
                            isActive: controller.isLiked.value,
                            onTap: () => controller.toggleLike(),
                          ),
                          _buildAction(
                            context,
                            Icons.share_rounded,
                            'Share',
                            onTap: () => Get.snackbar(
                              'Share',
                              'Sharing link: ${widget.videoUrl}',
                            ),
                          ),
                          _buildAction(
                            context,
                            Icons.download_rounded,
                            'Download',
                            onTap: () {
                              Get.bottomSheet(
                                DownloadQualitySheet(
                                  url: widget.videoUrl,
                                  title: controller.videoTitle.value,
                                ),
                                isScrollControlled: true,
                              );
                            },
                          ),
                          _buildAction(
                            context,
                            controller.isSaved.value
                                ? Icons.playlist_add_check_rounded
                                : Icons.playlist_add_rounded,
                            'Save',
                            isActive: controller.isSaved.value,
                            onTap: () => controller.toggleSave(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Video Description
                      _buildDescription(context, isDark),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
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

  Widget _buildGestureOverlay() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => _seekRelative(const Duration(seconds: -10)),
            child: Container(color: Colors.transparent),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => _seekRelative(const Duration(seconds: 10)),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  void _seekRelative(Duration duration) async {
    if (controller.podController == null) return;
    final vControl =
        (controller.podController as dynamic).videoPlayerController;
    if (vControl == null) return;

    final currentPos = vControl.value.position;
    final newPos = currentPos + duration;
    await (controller.podController as dynamic).videoPlayerController?.seekTo(
      newPos,
    );

    _showSeekFeedback(duration.inSeconds > 0);
  }

  void _showSeekFeedback(bool isForward) {
    Get.rawSnackbar(
      messageText: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      duration: const Duration(milliseconds: 500),
      snackPosition: SnackPosition.TOP,
      overlayBlur: 0,
    );
  }

  Widget _buildAction(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? UDesign.primary.withOpacity(0.2)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05)),
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                        color: UDesign.primary.withOpacity(0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive
                    ? UDesign.primary
                    : (isDark ? Colors.white : Colors.black87),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive
                    ? UDesign.primary
                    : (isDark ? Colors.white60 : Colors.black54),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context, bool isDark) {
    if (controller.videoDescription.value.isEmpty)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isDescriptionExpanded = !_isDescriptionExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Description',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isDescriptionExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  controller.videoDescription.value,
                  maxLines: _isDescriptionExpanded ? null : 3,
                  overflow: _isDescriptionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.5,
                  ),
                ),
                if (!_isDescriptionExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Show more',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: UDesign.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
