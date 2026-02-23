import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/design_system.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 4));
    Get.offNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with subtle animation
          Image.asset('assets/splash_bg.png', fit: BoxFit.cover)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                duration: const Duration(seconds: 10),
                curve: Curves.easeInOut,
              ),

          // Dark Overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: UDesign.primary.withOpacity(0.5),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(child: Image.asset('assets/app_icon.png')),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 800))
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.elasticOut,
                    duration: const Duration(seconds: 1),
                  )
                  .shimmer(
                    delay: const Duration(seconds: 2),
                    duration: const Duration(seconds: 2),
                  ),

              const SizedBox(height: 40),

              // App Name
              Text(
                    'uMusic',
                    style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: UDesign.primary.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 500),
                    duration: const Duration(milliseconds: 800),
                  )
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),

              const SizedBox(height: 10),

              // Tagline
              Text(
                'Your World of Music',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white70,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                ),
              ).animate().fadeIn(
                delay: const Duration(seconds: 1),
                duration: const Duration(milliseconds: 800),
              ),
            ],
          ),

          // Loading Indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child:
                Column(
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Initializing Experience...',
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(delay: const Duration(milliseconds: 2000))
                    .shimmer(duration: const Duration(seconds: 2)),
          ),
        ],
      ),
    );
  }
}
