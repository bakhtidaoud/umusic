import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'dart:io';

import 'services/native_service.dart';
import 'services/extraction_service.dart';
import 'controllers/config_controller.dart';
import 'controllers/download_controller.dart';
import 'controllers/subscription_controller.dart';
import 'controllers/cookie_controller.dart';
import 'controllers/library_controller.dart';
import 'screens/login_webview_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/downloader_screen.dart';
import 'screens/local_library_screen.dart';
import 'widgets/custom_drawer.dart';
import 'utils/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  await NativeService.initializeBinaries();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await initSystemTray();
  }

  // Initialize GetX Controllers
  Get.put(ConfigController(prefs));
  Get.put(DownloadController());
  Get.put(ExtractionService());
  Get.put(SubscriptionController(prefs));
  Get.put(CookieController());
  Get.put(LibraryController());

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
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: UDesign.primary,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.outfitTextTheme(),
        ),
        darkTheme: UDesign.darkTheme.copyWith(
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
  int _selectedIndex = 0;
  String? _prefetchedUrl;
  final PageController _pageController = PageController();

  final List<String> _titles = [
    'uMusic Home',
    'Downloader',
    'Local Library',
    'Subscriptions',
    'Browser',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
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
      backgroundColor: UDesign.background,
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.account_circle_outlined, size: 28),
                onPressed: () {
                  Get.to(
                    () => const LoginWebViewScreen(
                      initialUrl:
                          'https://accounts.google.com/ServiceLogin?service=youtube',
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      drawer: CustomDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutExpo,
          );
        },
      ),
      body: PageView(
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
    );
  }
}
