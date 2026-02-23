import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/design_system.dart';

class CustomDrawer extends StatelessWidget {
  final Function(int) onDestinationSelected;
  final int selectedIndex;

  const CustomDrawer({
    super.key,
    required this.onDestinationSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent, // Fully transparent for glass effect
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.75,
      child: UDesign.glassLayer(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
        child: Container(
          decoration: UDesign.glass(context: context).copyWith(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildDrawerItem(
                      context,
                      index: 0,
                      icon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    _buildDrawerItem(
                      context,
                      index: 1,
                      icon: Icons.download_rounded,
                      label: 'Downloader',
                    ),
                    _buildDrawerItem(
                      context,
                      index: 2,
                      icon: Icons.library_music_rounded,
                      label: 'Library',
                    ),
                    _buildDrawerItem(
                      context,
                      index: 3,
                      icon: Icons.subscriptions_rounded,
                      label: 'Subscriptions',
                    ),
                    _buildDrawerItem(
                      context,
                      index: 4,
                      icon: Icons.language_rounded,
                      label: 'Browser',
                    ),
                  ],
                ),
              ),
              const Divider(indent: 32, endIndent: 32, color: Colors.white10),
              _buildDrawerItem(
                context,
                index: 5,
                icon: Icons.settings_rounded,
                label: 'Settings',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [UDesign.primary.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'app_logo',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Image.asset('assets/app_icon.png', width: 48, height: 48),
            ),
          ).animate().shimmer(duration: const Duration(seconds: 2)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'uMusic',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
                ),
              ),
              Text(
                'High-End Experience',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: UDesign.primary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onDestinationSelected(index);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? UDesign.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(color: UDesign.primary.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? UDesign.primary
                    : (isDark ? UDesign.textMedDark : UDesign.textMedLight),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? UDesign.primary
                      : (isDark ? UDesign.textHighDark : UDesign.textHighLight),
                ),
              ),
              if (isSelected) const Spacer(),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: UDesign.primary,
                    shape: BoxShape.circle,
                  ),
                ).animate().scale().fadeIn(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.1, end: 0);
  }
}
