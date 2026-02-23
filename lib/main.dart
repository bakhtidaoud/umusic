import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'services/cache_service.dart';
import 'services/network_service.dart';
import 'services/native_service.dart';
import 'services/extraction_service.dart';
import 'controllers/config_controller.dart';
import 'controllers/download_controller.dart';
import 'controllers/subscription_controller.dart';
import 'services/geo_service.dart';
import 'controllers/cookie_controller.dart';
import 'controllers/library_controller.dart';
import 'controllers/player_controller.dart';
import 'screens/settings_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/downloader_screen.dart';
import 'screens/local_library_screen.dart';
import 'widgets/mini_player.dart';
import 'utils/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Background Audio
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.umusic.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  final prefs = await SharedPreferences.getInstance();

  await NativeService.initializeBinaries();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await initSystemTray();
  }

  // Initialize GetX Controllers & Services
  Get.put(ConfigController(prefs));
  await Get.putAsync(() => CacheService().init());
  await Get.putAsync(() => NetworkService().init());

  Get.put(NativeService());
  Get.put(DownloadController());
  Get.put(ExtractionService());
  Get.put(SubscriptionController(prefs));
  Get.put(CookieController());
  Get.put(LibraryController());
  Get.put(GeoService());
  Get.put(PlayerController()); // Global Player Controller

  runApp(const MyApp());
}

Future<void> initSystemTray() async {
  final SystemTray systemTray = SystemTray();
  await systemTray.initSystemTray(
    title: "uMusic",
    iconPath: Platform.isWindows
        ? 'assets/app_icon.ico'
        : 'assets/app_icon.png',
  );

  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(
      label: 'Show App',
      onClicked: (menuItem) => AppWindow().show(),
    ),
    MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
  ]);

  await systemTray.setContextMenu(menu);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configController = Get.find<ConfigController>();

    return Obx(() {
      final themeMode = _getThemeMode(configController.config.themeMode);

      return GetMaterialApp(
        title: 'uMusic',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: UDesign.premiumLight.copyWith(
          textTheme: GoogleFonts.outfitTextTheme(),
        ),
        darkTheme: UDesign.premiumDark.copyWith(
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        ),
        home: const MyHomePage(title: 'uMusic'),
      );
    });
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PageController _pageController = PageController();
  final String? _prefetchedUrl = null;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initServices();
    _checkClipboardForLinks();
  }

  Future<void> _checkClipboardForLinks() async {
    // Wait a bit for the app to settle
    await Future.delayed(const Duration(seconds: 1));
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text != null &&
        (text.contains('youtube.com') || text.contains('youtu.be'))) {
      Get.snackbar(
        'Link Detected',
        'Found a video link in your clipboard. Download?',
        mainButton: TextButton(
          onPressed: () {
            _pageController.jumpToPage(1); // Go to Downloader
            Get.back();
          },
          child: const Text(
            'OPEN',
            style: TextStyle(
              color: UDesign.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
    }
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Request storage and notification permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.notification,
        // For Android 13+ (API 33+)
        Permission.manageExternalStorage,
      ].request();

      if (statuses[Permission.storage]!.isDenied) {
        Get.snackbar(
          'Permission Needed',
          'Storage permission is required to download and play music.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _initServices() {
    final configController = Get.find<ConfigController>();
    final downloadController = Get.find<DownloadController>();
    final cookieController = Get.find<CookieController>();
    final extractionController = Get.find<ExtractionService>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      downloadController.updateMaxConcurrent(
        configController.config.maxConcurrentDownloads,
      );
      downloadController.updateDownloadFolder(
        configController.config.downloadFolder,
      );
      downloadController.updateProxy(configController.config.proxySettings);
      extractionController.setProxy(configController.config.proxySettings);

      final cookies = await cookieController.getCookieString(
        Uri.parse('https://www.youtube.com'),
      );
      extractionController.setCookies(cookies);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const HomeScreen(),
              DownloaderScreen(initialUrl: _prefetchedUrl),
              const LocalLibraryScreen(),
              const SubscriptionsScreen(),
              const BrowserScreen(),
              const SettingsScreen(),
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
    );
  }
}
