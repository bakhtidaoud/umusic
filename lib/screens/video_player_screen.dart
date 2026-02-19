import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pod_player/pod_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/player_controller.dart';

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
    controller = Get.put(PlayerController());
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
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PodVideoPlayer(controller: controller.podController),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0B14),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.videoTitle.value,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.channelName.value,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAction(Icons.thumb_up_outlined, 'Like'),
                          _buildAction(Icons.share_outlined, 'Share'),
                          _buildAction(Icons.download_outlined, 'Download'),
                          _buildAction(Icons.playlist_add_outlined, 'Save'),
                        ],
                      ),
                      const Divider(height: 48, color: Colors.white10),
                      // Audio-only toggle or info could go here
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Icon(Icons.music_note, color: Colors.white),
                        ),
                        title: Text(
                          'Audio Only Mode',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Switch to background audio playback',
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Switch(value: false, onChanged: (v) {}),
                      ),
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
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
