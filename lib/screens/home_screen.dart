import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../controllers/home_controller.dart';
import '../utils/design_system.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      backgroundColor: UDesign.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(context, controller),
              _buildCategoryBar(controller),
              Expanded(
                child: RefreshIndicator(
                  color: UDesign.primary,
                  backgroundColor: UDesign.surface,
                  onRefresh: () => controller.fetchVideos(),
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return _buildShimmerLoading();
                    }
                    return _buildMainList(controller);
                  }),
                ),
              ),
            ],
          ),
          // Suggestions Overlay
          Obx(() {
            if (!controller.showSuggestions.value ||
                controller.suggestions.isEmpty) {
              return const SizedBox.shrink();
            }
            return _buildSuggestionsOverlay(controller);
          }),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: UDesign.glassMaterial(
        borderRadius: UDesign.brLarge,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: UDesign.brLarge,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller.searchController,
            onSubmitted: (query) => controller.search(query),
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search high-quality videos...',
              hintStyle: GoogleFonts.outfit(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: UDesign.primary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 15,
              ),
              suffixIcon: Obx(
                () => controller.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                        ),
                        onPressed: () {
                          controller.searchController.clear();
                          controller.search('');
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildCategoryBar(HomeController controller) {
    return SizedBox(
      height: 50,
      child: Obx(
        () => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: controller.categories.length,
          itemBuilder: (context, index) {
            final category = controller.categories[index];
            final isSelected = controller.currentCategory.value == category;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: InkWell(
                onTap: () => controller.setCategory(category),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? UDesign.primary
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? UDesign.primary
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainList(HomeController controller) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount:
            controller.videos.length + (controller.shorts.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // Insert Shorts section after the first 2 videos
          if (controller.shorts.isNotEmpty && index == 2) {
            return _buildShortsSection(controller);
          }

          final videoIndex = (controller.shorts.isNotEmpty && index > 2)
              ? index - 1
              : index;
          if (videoIndex >= controller.videos.length)
            return const SizedBox.shrink();

          final video = controller.videos[videoIndex];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(child: _buildVideoCard(context, video)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShortsSection(HomeController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Shorts',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.shorts.length,
            itemBuilder: (context, index) {
              final video = controller.shorts[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () =>
                      Get.to(() => VideoPlayerScreen(videoUrl: video.url)),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: UDesign.premiumShadows(),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnails.highResUrl,
                            height: double.infinity,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, dynamic video) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: InkWell(
        onTap: () => Get.to(() => VideoPlayerScreen(videoUrl: video.url)),
        borderRadius: UDesign.brLarge,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: UDesign.brLarge,
            boxShadow: UDesign.premiumShadows(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: UDesign.brLarge,
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnails.highResUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 220,
                        color: UDesign.surface,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 220,
                        color: UDesign.surface,
                        child: const Icon(Icons.broken_image_rounded, size: 48),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: UDesign.glassMaterial(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        color: Colors.black45,
                        child: Text(
                          video.duration?.toString().split('.').first ??
                              '--:--',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: UDesign.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: UDesign.surface,
                        child: Text(
                          video.author[0].toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: UDesign.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${video.author} • ${video.engagement.viewCount.toString()} views',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(
      begin: const Offset(0.95, 0.95),
      curve: Curves.easeOut,
    );
  }

  Widget _buildSuggestionsOverlay(HomeController controller) {
    return Positioned(
      top: 80, // Adjust based on search bar height
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: UDesign.glassMaterial(
          borderRadius: UDesign.brMedium,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: UDesign.surface.withOpacity(0.95),
              borderRadius: UDesign.brMedium,
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controller.suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = controller.suggestions[index];
                return ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: Colors.white38,
                  ),
                  title: Text(
                    suggestion,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () => controller.search(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: UDesign.surface,
          highlightColor: UDesign.surface.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: UDesign.brLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 18,
                            width: double.infinity,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: 140,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
