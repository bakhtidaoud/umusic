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
import 'screens/login_webview_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/downloader_screen.dart';
import 'widgets/custom_drawer.dart';

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
            seedColor: const Color(0xFF673AB7),
            brightness: Brightness.light,
            surface: const Color(0xFFFBF9FF),
          ),
          textTheme: GoogleFonts.outfitTextTheme(),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: ZoomPageTransitionsBuilder(),
              TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD1C4E9),
            brightness: Brightness.dark,
            surface: const Color(0xFF0D0B14),
            primary: const Color(0xFFBB86FC),
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: ZoomPageTransitionsBuilder(),
              TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            },
          ),
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
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () {
                Get.to(
                  () => const LoginWebViewScreen(
                    initialUrl:
                        'https://accounts.google.com/ServiceLogin?service=youtube',
                  ),
                );
              },
            ),
        ],
      ),
      drawer: CustomDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          _pageController.jumpToPage(index);
        },
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const HomeScreen(),
          DownloaderScreen(initialUrl: _prefetchedUrl),
          const SubscriptionsScreen(),
          const BrowserScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
