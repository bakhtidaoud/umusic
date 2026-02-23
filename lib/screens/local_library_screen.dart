import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:math' as math;
import '../controllers/library_controller.dart';
import '../utils/design_system.dart';
import 'video_player_screen.dart';

class LocalLibraryScreen extends StatelessWidget {
  const LocalLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LibraryController());
    final TextEditingController searchTeco = TextEditingController();
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(context, controller, searchTeco),
          Expanded(
            child: RefreshIndicator(
              color: UDesign.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onRefresh: () => controller.scanFiles(),
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.filteredFiles.isEmpty) {
                  return _buildEmptyState(context);
                }

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: controller.filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = controller.filteredFiles[index];
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 500),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildFileCard(context, file, controller),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    LibraryController controller,
    TextEditingController teco,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: UDesign.glassLayer(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: UDesign.glass(context: context),
          child: TextField(
            controller: teco,
            onChanged: (val) => controller.search(val),
            style: GoogleFonts.outfit(
              color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
            ),
            decoration: InputDecoration(
              hintText: 'Search local library...',
              hintStyle: GoogleFonts.outfit(
                color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: UDesign.primary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 15,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: UDesign.primary),
                onPressed: () => controller.scanFiles(),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  Widget _buildFileCard(
    BuildContext context,
    LocalFile file,
    LibraryController controller,
  ) {
    final isVideo = ['.mp4', '.mkv', '.webm'].contains(file.extension);
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          if (isVideo) {
            Get.to(() => VideoPlayerScreen(videoUrl: file.path));
          } else {
            Get.snackbar(
              'Audio Player',
              'Audio playback coming soon!',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        },
        onLongPress: () => _confirmDelete(context, file, controller),
        borderRadius: BorderRadius.circular(24),
        child: UDesign.glassLayer(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: UDesign.glass(context: context),
            child: Row(
              children: [
                _buildThumbnail(context, file, isVideo),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? UDesign.textHighDark
                              : UDesign.textHighLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatSize(file.size)} • ${file.extension.toUpperCase().replaceAll('.', '')}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark
                              ? UDesign.textMedDark
                              : UDesign.textMedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.audiotrack_rounded,
                  color: UDesign.primary.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, LocalFile file, bool isVideo) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: file.thumbnailPath != null
            ? Image.file(File(file.thumbnailPath!), fit: BoxFit.cover)
            : Icon(
                isVideo
                    ? Icons.movie_creation_rounded
                    : Icons.music_note_rounded,
                color: isDark ? Colors.white24 : Colors.black.withOpacity(0.24),
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_rounded,
            size: 80,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 20),
          Text(
            'Library is empty',
            style: GoogleFonts.outfit(
              fontSize: 20,
              color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Go download some awesome content!',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes.toDouble()) / math.log(1024)).floor();
    return ((bytes / math.pow(1024, i)).toStringAsFixed(1)) + " " + suffixes[i];
  }

  void _confirmDelete(
    BuildContext context,
    LocalFile file,
    LibraryController controller,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete File?',
          style: GoogleFonts.outfit(
            color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${file.name}" permanentely?',
          style: GoogleFonts.outfit(
            color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.deleteFile(file);
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
