import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';
import 'package:flutter/material.dart';

import 'services/download_service.dart';
import 'services/extraction_service.dart';
import 'services/native_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Initialize native binaries (yt-dlp, ffmpeg) for Desktop support
  await NativeService.initializeBinaries();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService(prefs)),
        ChangeNotifierProvider(create: (_) => DownloadService()),
        ChangeNotifierProvider(create: (_) => ExtractionService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context);
    final themeMode = _getThemeMode(configService.config.themeMode);

    return MaterialApp(
      title: 'uMusic',
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'uMusic Home'),
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _ytController = TextEditingController(
    text: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
  );
  UniversalMetadata? _currentMetadata;
  bool _isLoading = false;
  bool _downloadSubtitles = true;
  bool _downloadThumbnail = false;

  Future<void> _fetchVideoInfo() async {
    setState(() => _isLoading = true);
    final extService = Provider.of<ExtractionService>(context, listen: false);
    final meta = await extService.getMetadata(_ytController.text);
    setState(() {
      _currentMetadata = meta;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final configService = context.watch<ConfigService>();

    // Keep max concurrency in sync
    if (downloadService.maxConcurrentDownloads !=
        configService.config.maxConcurrentDownloads) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        downloadService.updateMaxConcurrent(
          configService.config.maxConcurrentDownloads,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigation to settings
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'uMusic Universal Downloader',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Search/Extraction Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ytController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'Enter URL (Video or Playlist)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _ytController.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _fetchVideoInfo,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('Fetch Metadata'),
                    ),
                  ],
                ),
              ),
            ),

            if (_currentMetadata != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: _currentMetadata!.thumbnailUrl != null
                          ? Image.network(
                              _currentMetadata!.thumbnailUrl!,
                              width: 80,
                            )
                          : const Icon(Icons.movie),
                      title: Text(
                        _currentMetadata!.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _currentMetadata!.isPlaylist
                            ? '${_currentMetadata!.entries.length} items'
                            : (_currentMetadata!.author ?? "Unknown author"),
                      ),
                    ),
                    if (!_currentMetadata!.isPlaylist) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text(
                                  'Subtitles (SRT)',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _downloadSubtitles,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setState(
                                  () => _downloadSubtitles = v ?? false,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text(
                                  'Thumbnail',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _downloadThumbnail,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setState(
                                  () => _downloadThumbnail = v ?? false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            downloadService.downloadFile(
                              _currentMetadata!.originalUrl,
                              fileName: '${_currentMetadata!.title}.mp4',
                              downloadSubtitles: _downloadSubtitles,
                              downloadThumbnail: _downloadThumbnail,
                              videoId: _currentMetadata!.videoId,
                              isYoutube: _currentMetadata!.isYoutube,
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download Best Quality'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              for (var e in _currentMetadata!.entries) {
                                e.isSelected = true;
                              }
                            }),
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              for (var e in _currentMetadata!.entries) {
                                e.isSelected = false;
                              }
                            }),
                            child: const Text('Deselect All'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              downloadService.downloadBatch(
                                _currentMetadata!.entries,
                              );
                            },
                            child: const Text('Download Selected'),
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _currentMetadata!.entries.length,
                          itemBuilder: (context, index) {
                            final entry = _currentMetadata!.entries[index];
                            return CheckboxListTile(
                              title: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(entry.url),
                              value: entry.isSelected,
                              onChanged: (val) {
                                setState(() => entry.isSelected = val ?? false);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const Divider(height: 40),

            // Active Downloads Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Downloads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Limit: ${downloadService.maxConcurrentDownloads}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (downloadService.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No active downloads',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...downloadService.tasks.values
                  .toList()
                  .reversed
                  .map(
                    (task) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  task.status == DownloadStatus.completed
                                      ? Icons.check_circle
                                      : Icons.file_download,
                                  color: task.status == DownloadStatus.completed
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    task.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(task.progress * 100).toStringAsFixed(1)}%',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: task.progress,
                              backgroundColor: Colors.grey.shade200,
                              color: task.status == DownloadStatus.error
                                  ? Colors.red
                                  : null,
                            ),
                            if (task.errorMessage != null)
                              Text(
                                task.errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (task.status == DownloadStatus.downloading)
                                  IconButton(
                                    icon: const Icon(Icons.pause),
                                    onPressed: () =>
                                        downloadService.pauseDownload(task.url),
                                  )
                                else if (task.status == DownloadStatus.paused)
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => downloadService
                                        .resumeDownload(task.url),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.cancel),
                                  onPressed: () =>
                                      downloadService.cancelDownload(task.url),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
          ],
        ),
      ),
    );
  }
}
