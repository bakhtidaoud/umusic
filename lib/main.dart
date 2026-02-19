import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';
import 'package:flutter/material.dart';

import 'services/download_service.dart';
import 'services/extraction_service.dart';
import 'services/native_service.dart';
import 'services/cookie_service.dart';
import 'screens/login_webview_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/subscription_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

import 'screens/home_screen.dart';
import 'screens/downloader_screen.dart';
import 'widgets/custom_drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  await NativeService.initializeBinaries();

  final cookieService = CookieService();
  await cookieService.init();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await initSystemTray();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService(prefs)),
        ChangeNotifierProvider(create: (_) => DownloadService()),
        ChangeNotifierProvider(create: (context) => ExtractionService()),
        ProxyProvider2<ExtractionService, DownloadService, SubscriptionService>(
          update: (context, extraction, download, previous) =>
              previous ?? SubscriptionService(prefs, extraction, download),
        ),
        ChangeNotifierProvider.value(value: cookieService),
      ],
      child: const MyApp(),
    ),
  );
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
    final configService = Provider.of<ConfigService>(context);
    final themeMode = _getThemeMode(configService.config.themeMode);

    return MaterialApp(
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
    final configService = Provider.of<ConfigService>(context, listen: false);
    final downloadService = Provider.of<DownloadService>(
      context,
      listen: false,
    );
    final cookieService = Provider.of<CookieService>(context, listen: false);
    final extractionService = Provider.of<ExtractionService>(
      context,
      listen: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      downloadService.updateMaxConcurrent(
        configService.config.maxConcurrentDownloads,
      );
      downloadService.updateDownloadFolder(configService.config.downloadFolder);
      downloadService.updateProxy(configService.config.proxySettings);
      extractionService.setProxy(configService.config.proxySettings);

      final cookies = await cookieService.getCookieString(
        Uri.parse('https://www.youtube.com'),
      );
      extractionService.setCookies(cookies);
    });
  }

  void _onVideoSelected(String url) {
    setState(() {
      _prefetchedUrl = url;
      _selectedIndex = 1;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginWebViewScreen(
                      initialUrl:
                          'https://accounts.google.com/ServiceLogin?service=youtube',
                    ),
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
          HomeScreen(onVideoSelected: _onVideoSelected),
          DownloaderScreen(initialUrl: _prefetchedUrl),
          const SubscriptionsScreen(),
          const BrowserScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
