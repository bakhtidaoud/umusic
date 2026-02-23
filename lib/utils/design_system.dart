import 'package:flutter/material.dart';
import 'dart:ui';

class UDesign {
  // --- Sophisticated Color Palette ---

  // Dark Neutrals
  static const Color darkBg = Color(0xFF0A090F);
  static const Color darkSurface = Color(0xFF14121F);
  static const Color darkAccent = Color(0xFF1D1B2B);

  // Light Neutrals (Premium Light Mode)
  static const Color lightBg = Color(0xFFF1F5F9); // Very Soft Slate/White
  static const Color lightSurface = Colors.white;
  static const Color lightAccent = Color(0xFFE2E8F0); // Soft Border/Surface

  // Brand Colors
  static const Color primary = Color(0xFF6366F1); // Deep Indigo
  static const Color secondary = Color(0xFFA855F7); // Vibrant Violet
  static const Color accent = Color(0xFF22D3EE); // Pure Cyan

  // Text Colors
  static const Color textHighDark = Color(0xFFF8FAFC);
  static const Color textMedDark = Color(0xFF94A3B8);
  static const Color textHighLight = Color(0xFF0F172A); // Deep Navy/Black
  static const Color textMedLight = Color(0xFF475569); // Slate Grey

  // --- Gradients ---
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Elevation & Shadows ---
  static List<BoxShadow> softShadow(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.4)
            : Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  // --- Glassmorphism ---
  static BoxDecoration glass({
    required BuildContext context,
    double opacity = 0.1,
    BorderRadius? borderRadius,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(opacity)
          : Colors.white.withOpacity(0.7), // More solid white for light mode
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
        width: 0.5,
      ),
    );
  }

  static Widget glassLayer({
    required Widget child,
    double blur = 15.0,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }

  // --- Shimmer Effect (Utility for Loading) ---
  static Widget shimmer({required Widget child, required bool isDarkMode}) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: isDarkMode
              ? [darkAccent, darkSurface, darkAccent]
              : [lightAccent, lightSurface, lightAccent],
          stops: const [0.1, 0.5, 0.9],
        ).createShader(bounds);
      },
      child: child,
    );
  }

  // --- Typography ---
  static TextStyle h1(BuildContext context) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: Theme.of(context).brightness == Brightness.dark
        ? textHighDark
        : textHighLight,
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).brightness == Brightness.dark
        ? textMedDark
        : textMedLight,
  );

  // --- Themes ---
  static ThemeData get premiumDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkSurface,
        onSurface: textHighDark,
        surfaceContainerHigh: darkAccent,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get premiumLight {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: primary,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: lightSurface,
        onSurface: textHighLight,
        surfaceContainerHigh: lightAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textHighLight),
        titleTextStyle: TextStyle(
          color: textHighLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withOpacity(0.05), width: 0.5),
        ),
      ),
    );
  }
}

// --- Micro-Interactions & Animations ---
class UAnim extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const UAnim({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
