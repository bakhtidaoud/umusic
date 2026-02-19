import 'package:flutter/material.dart';
import 'dart:ui';

class UDesign {
  // --- Colors (HSL Inspired) ---
  static const Color background = Color(0xFF0D0B14);
  static const Color surface = Color(0xFF1A1625);
  static const Color primary = Color(0xFFBB86FC);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color accent = Color(0xFFFF4081);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);

  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBlack = Color(0x4D000000);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6200EE), Color(0xFFBB86FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [glassWhite, Colors.transparent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Spacing & Radius ---
  static const double ptLarge = 32.0;
  static const double ptMedium = 24.0;
  static const double ptSmall = 16.0;

  static final BorderRadius brLarge = BorderRadius.circular(32.0);
  static final BorderRadius brMedium = BorderRadius.circular(24.0);
  static final BorderRadius brSmall = BorderRadius.circular(16.0);

  // --- Decorations ---
  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color? color,
    double blur = 10.0,
  }) {
    return BoxDecoration(
      color: color ?? glassWhite,
      borderRadius: borderRadius ?? brMedium,
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
    );
  }

  static List<BoxShadow> premiumShadows() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: primary.withOpacity(0.1),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ];
  }

  // --- Glass Widget ---
  static Widget glassMaterial({
    required Widget child,
    BorderRadius? borderRadius,
    double blur = 15.0,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? brMedium,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }

  // --- Theme ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: brMedium),
        elevation: 0,
      ),
    );
  }
}
