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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:system_tray/system_tray.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

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
  final TextEditingController _urlController = TextEditingController();
  UniversalMetadata? _currentMetadata;
  bool _isLoading = false;
  String _selectedFormatType = 'video'; // 'video' or 'audio'
  YtDlpFormat? _selectedQuality;

  bool _downloadSubtitles = true;
  bool _downloadThumbnail = false;

  Future<void> _fetchMetadata() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final extService = Provider.of<ExtractionService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    final meta = await extService.getMetadata(_urlController.text);
    setState(() {
      _currentMetadata = meta;
      _isLoading = false;
      if (meta != null && meta.formats.isNotEmpty) {
        // Apply Smart Mode if enabled
        if (configService.config.smartModeEnabled &&
            configService.config.lastFormatType != null &&
            configService.config.lastQualityId != null) {
          _selectedFormatType = configService.config.lastFormatType!;
          final lastId = configService.config.lastQualityId;
          _selectedQuality = meta.formats.firstWhere(
            (f) => f.formatId == lastId || f.resolution == lastId,
            orElse: () => meta.formats.first,
          );

          // Auto-start download
          _startDownload(context);
        } else {
          _selectedQuality = meta.formats.first;
        }
      }
    });
  }

  void _startDownload(BuildContext context) {
    if (_currentMetadata == null || _selectedQuality == null) return;

    final downloadService = Provider.of<DownloadService>(
      context,
      listen: false,
    );
    final configService = Provider.of<ConfigService>(context, listen: false);

    // Save settings if successful
    configService.setLastSettings(
      _selectedFormatType,
      _selectedQuality!.formatId ?? _selectedQuality!.resolution ?? 'best',
    );

    downloadService.downloadFile(
      _getDownloadUrl(),
      fileName: '${_currentMetadata!.title}.${_selectedQuality?.ext ?? 'mp4'}',
      downloadSubtitles: _downloadSubtitles,
      downloadThumbnail: _downloadThumbnail,
      videoId: _currentMetadata!.videoId,
      isYoutube: _currentMetadata!.isYoutube,
    );

    if (configService.config.smartModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Smart Mode: Downloading ${_currentMetadata!.title}'),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      _fetchMetadata();
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final configService = context.watch<ConfigService>();
    final cookieService = context.watch<CookieService>();
    final extractionService = Provider.of<ExtractionService>(
      context,
      listen: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (downloadService.maxConcurrentDownloads !=
          configService.config.maxConcurrentDownloads) {
        downloadService.updateMaxConcurrent(
          configService.config.maxConcurrentDownloads,
        );
      }
      downloadService.updateDownloadFolder(configService.config.downloadFolder);
      downloadService.updateProxy(configService.config.proxySettings);
      extractionService.setProxy(configService.config.proxySettings);
      final cookies = await cookieService.getCookieString(
        Uri.parse('https://www.youtube.com'),
      );
      extractionService.setCookies(cookies);
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SvgPicture.asset('assets/app_icon.svg'),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              configService.config.smartModeEnabled
                  ? Icons.tips_and_updates
                  : Icons.tips_and_updates_outlined,
            ),
            tooltip: 'Smart Mode',
            color: configService.config.smartModeEnabled ? Colors.amber : null,
            onPressed: () => configService.setSmartMode(
              !configService.config.smartModeEnabled,
            ),
          ),
          IconButton(
            icon: Icon(
              configService.config.themeMode == 'dark'
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              final newMode = configService.config.themeMode == 'dark'
                  ? 'light'
                  : 'dark';
              configService.setThemeMode(newMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.subscriptions),
            tooltip: 'Subscriptions',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.public),
            tooltip: 'Browser',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrowserScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Login (Cookies)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginWebViewScreen(
                  initialUrl: 'https://www.youtube.com',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: configService.config.themeMode == 'dark'
                ? [
                    const Color(0xFF0D0B14),
                    const Color(0xFF1A1625),
                    const Color(0xFF0D0B14),
                  ]
                : [
                    const Color(0xFFFBF9FF),
                    const Color(0xFFF0E7FF),
                    const Color(0xFFFBF9FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // URL Input Section
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Paste video or playlist link',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton.filledTonal(
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 20,
                          ),
                          tooltip: 'Paste',
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onSubmitted: (_) => _fetchMetadata(),
                  ),
                ),
                const SizedBox(height: 20),

                Animate(
                  effects: const [
                    FadeEffect(),
                    ScaleEffect(begin: Offset(0.95, 0.95)),
                  ],
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchMetadata,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text(
                      'Analyze Content',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 8,
                      shadowColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                if (_currentMetadata != null) ...[
                  const SizedBox(height: 32),
                  _buildMetadataCard(context, downloadService),
                ] else if (downloadService.tasks.isEmpty) ...[
                  const SizedBox(height: 60),
                  Animate(
                    effects: const [
                      FadeEffect(duration: Duration(seconds: 1)),
                      ScaleEffect(
                        begin: Offset(0.8, 0.8),
                        duration: Duration(seconds: 1),
                      ),
                    ],
                    child: Center(
                      child: Opacity(
                        opacity: 0.1,
                        child: SvgPicture.asset(
                          'assets/app_icon.svg',
                          width: 200,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                _buildActiveDownloadsSection(context, downloadService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataCard(
    BuildContext context,
    DownloadService downloadService,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 500)),
        SlideEffect(begin: Offset(0, 0.1), end: Offset.zero),
      ],
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.05),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _currentMetadata!.thumbnailUrl != null
                        ? Image.network(
                            _currentMetadata!.thumbnailUrl!,
                            width: 140,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 140,
                            height: 80,
                            color: colorScheme.surfaceVariant,
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 40,
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
                        _currentMetadata!.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _currentMetadata!.author ?? 'Unknown Creator',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (!_currentMetadata!.isPlaylist) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFormatType,
                      decoration: InputDecoration(
                        labelText: 'Content Type',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: colorScheme.primary.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'video',
                          child: Text('Video', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'audio',
                          child: Text('Audio', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedFormatType = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<YtDlpFormat>(
                      value: _selectedQuality,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Set Quality',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: colorScheme.primary.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      items: _currentMetadata!.formats.map((f) {
                        return DropdownMenuItem(
                          value: f,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text(
                                  '${f.resolution ?? f.ext}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (f.isHdr) ...[
                                  const SizedBox(width: 4),
                                  _buildBadge('HDR', Colors.orange),
                                ],
                                if (f.is360) ...[
                                  const SizedBox(width: 4),
                                  _buildBadge('360°', Colors.blue),
                                ],
                                if (f.is3d) ...[
                                  const SizedBox(width: 4),
                                  _buildBadge('3D', Colors.purple),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedQuality = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedQuality?.isHdr ?? false)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_rounded,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'HDR requires specialized players like VLC for correct colors.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildGlassSwitch(
                      'Subtitles',
                      _downloadSubtitles,
                      (v) => setState(() => _downloadSubtitles = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassSwitch(
                      'Thumbnail',
                      _downloadThumbnail,
                      (v) => setState(() => _downloadThumbnail = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _startDownload(context),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Initialize Download',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Divider(),
              Text(
                '${_currentMetadata!.entries.length} items in playlist',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _currentMetadata!.entries.forEach(
                        (e) => e.isSelected = true,
                      ),
                    ),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _currentMetadata!.entries.forEach(
                        (e) => e.isSelected = false,
                      ),
                    ),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              FilledButton(
                onPressed: () =>
                    downloadService.downloadBatch(_currentMetadata!.entries),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Download Selected'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDownloadUrl() {
    // If it's a direct URL from extraction, use it.
    // For yt-dlp, some formats might need another step but here we use the original URL
    // and let the downloader handle the format selection if possible, or use the format URL.
    return _currentMetadata!.originalUrl;
  }

  Widget _buildActiveDownloadsSection(
    BuildContext context,
    DownloadService service,
  ) {
    if (service.tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Downloads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Max: ${service.maxConcurrentDownloads}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: service.tasks.length,
          itemBuilder: (context, index) {
            final task = service.tasks.values.toList().reversed.toList()[index];
            return DownloadItem(task: task, service: service);
          },
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGlassSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final DownloadService service;

  const DownloadItem({super.key, required this.task, required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  task.status == DownloadStatus.completed
                      ? Icons.check_circle
                      : Icons.downloading,
                  color: task.status == DownloadStatus.completed
                      ? Colors.green
                      : colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: task.status == DownloadStatus.error
                              ? Colors.red
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: task.progress,
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceVariant,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (task.status == DownloadStatus.downloading) ...[
                  Icon(
                    Icons.speed,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatSpeed(task.transferRate),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatEta(task.eta),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (task.status == DownloadStatus.downloading)
                  _ActionButton(
                    icon: Icons.pause_rounded,
                    onPressed: () => service.pauseDownload(task.url),
                  )
                else if (task.status == DownloadStatus.paused)
                  _ActionButton(
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => service.resumeDownload(task.url),
                  ),

                _ActionButton(
                  icon: Icons.folder_open_rounded,
                  onPressed: () => service.openFileFolder(task.url),
                  tooltip: 'Open Folder',
                ),
                _ActionButton(
                  icon: Icons.close_rounded,
                  color: Colors.red.withOpacity(0.7),
                  onPressed: () => service.cancelDownload(task.url),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  String _getStatusText() {
    if (task.status == DownloadStatus.error)
      return 'Error: ${task.errorMessage}';
    return task.status.name.toUpperCase();
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return "-- KB/s";
    if (bytesPerSec < 1024 * 1024) {
      return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    }
    return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return "--:--";
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final String? tooltip;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
    );
  }
}
