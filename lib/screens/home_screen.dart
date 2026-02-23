import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../controllers/home_controller.dart';
import '../controllers/cookie_controller.dart';
import '../utils/design_system.dart';
import '../widgets/video_card.dart';
import '../services/network_service.dart';
import 'browser_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    final cookieController = Get.find<CookieController>();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, controller, cookieController),
              _buildSliverCategories(controller),
              SliverToBoxAdapter(
                child: Obx(() {
                  final networkService = Get.find<NetworkService>();
                  if (!networkService.isConnected.value &&
                      controller.videos.isEmpty) {
                    return _buildOfflineContent(context);
                  }

                  if (controller.isLoading.value) {
                    return _buildShimmerLoading(context);
                  }
                  if (controller.videos.isEmpty && controller.shorts.isEmpty) {
                    return _buildEmptyState(context, controller);
                  }
                  return Column(
                    children: [
                      if (!controller.isLoggedIn.value &&
                          controller.currentQuery.value == 'trending music')
                        _buildLoginPrompt(context),
                      const SizedBox.shrink(),
                    ],
                  );
                }),
              ),
              Obx(() {
                final networkService = Get.find<NetworkService>();
                if (!networkService.isConnected.value &&
                    controller.videos.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return _buildVideoGrid(context, controller);
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          // Offline Banner
          _buildOfflineBanner(),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final networkService = Get.find<NetworkService>();
    return Obx(() {
      if (networkService.isConnected.value) return const SizedBox.shrink();
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.only(top: 50, bottom: 8),
          color: Colors.redAccent.withOpacity(0.9),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Offline Mode - Some content may not be available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: -1, end: 0),
      );
    });
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    HomeController controller,
    CookieController cookieController,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 220,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [UDesign.darkBg, UDesign.darkSurface.withOpacity(0.8)]
                  : [UDesign.lightBg, UDesign.lightSurface.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: UDesign.primary.withOpacity(0.05),
                  ),
                ),
              ).animate().scale(
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(cookieController),
                    const SizedBox(height: 20),
                    _buildSearchBar(context, controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(CookieController cookieController) {
    return FutureBuilder<String?>(
      future: cookieController.getCookieString(
        Uri.parse('https://www.youtube.com'),
      ),
      builder: (context, snapshot) {
        bool isLoggedIn = snapshot.hasData && snapshot.data != null;
        bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLoggedIn ? 'Welcome back,' : 'Welcome to,',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: UDesign.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              isLoggedIn ? 'Music Lover' : 'uMusic Premium',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
                letterSpacing: -1,
              ),
            ),
          ],
        ).animate().fadeIn().slideX(begin: -0.1);
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, HomeController controller) {
    return UDesign.glassLayer(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: UDesign.glass(context: context),
        child: TextField(
          controller: controller.searchController,
          onSubmitted: (query) => controller.search(query),
          decoration: InputDecoration(
            hintText: 'Search for music or videos...',
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
          ),
        ),
      ),
    );
  }

  Widget _buildSliverCategories(HomeController controller) {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: controller.categories.length,
          itemBuilder: (context, index) {
            final category = controller.categories[index];
            return Obx(() {
              final isSelected = controller.currentCategory.value == category;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: InkWell(
                  onTap: () => controller.setCategory(category),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? UDesign.primary
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? UDesign.primary
                            : Colors.white.withOpacity(0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: UDesign.primary.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ).animate().scale(begin: const Offset(0.9, 0.9)),
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildVideoGrid(BuildContext context, HomeController controller) {
    if (controller.videos.isEmpty && controller.shorts.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Index logic to inject Shorts
            if (controller.shorts.isNotEmpty && index == 1) {
              return _buildShortsSection(context, controller);
            }

            final videoIndex = (controller.shorts.isNotEmpty && index > 1)
                ? index - 1
                : index;
            if (videoIndex >= controller.videos.length) return null;

            final video = controller.videos[videoIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 600),
                child: SlideAnimation(
                  verticalOffset: 50,
                  child: FadeInAnimation(child: VideoCard(video: video)),
                ),
              ),
            );
          },
          childCount:
              controller.videos.length + (controller.shorts.isNotEmpty ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildShortsSection(BuildContext context, HomeController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Shorts Blast',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: controller.shorts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 500),
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: VideoCard(
                        video: controller.shorts[index],
                        isShort: true,
                      ),
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

  Widget _buildEmptyState(BuildContext context, HomeController controller) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            'No vibes found',
            style: GoogleFonts.outfit(fontSize: 20, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => controller.fetchVideos(),
            child: const Text('Refresh Library'),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildSuggestionsOverlay(HomeController controller) {
    return Positioned(
      top: 155,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: UDesign.glassLayer(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: UDesign.glass(context: Get.context!),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controller.suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: Colors.white38,
                  ),
                  title: Text(
                    controller.suggestions[index],
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => controller.search(controller.suggestions[index]),
                );
              },
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(3, (index) => _buildSingleShimmer(context)),
      ),
    );
  }

  Widget _buildSingleShimmer(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 150,
                          color: Colors.white12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: Colors.white.withOpacity(0.05),
        );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: UDesign.glassLayer(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: UDesign.glass(context: context, opacity: 0.05),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UDesign.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: UDesign.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalize Your Experience',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? UDesign.textHighDark
                            : UDesign.textHighLight,
                      ),
                    ),
                    Text(
                      'Login to see your subscriptions and recommendations.',
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
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Get.to(
                  () => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        'YouTube Login',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    body: const BrowserScreen(
                      initialUrl:
                          'https://accounts.google.com/ServiceLogin?service=youtube',
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UDesign.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildOfflineContent(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: UDesign.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: UDesign.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Connection',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'It seems you are offline. You can still enjoy your downloaded content in the library.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Get.find<PageController>().jumpToPage(2);
              },
              icon: const Icon(
                Icons.library_music_rounded,
                color: Colors.black,
              ),
              label: const Text('See My Downloads'),
              style: ElevatedButton.styleFrom(
                backgroundColor: UDesign.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ).animate().shimmer(delay: const Duration(seconds: 1), duration: const Duration(seconds: 2)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 800));
  }
}
