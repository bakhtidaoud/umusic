import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';
import 'package:flutter/material.dart';

import 'services/download_service.dart';
import 'services/youtube_service.dart';
import 'models/video_metadata.dart';

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
        ChangeNotifierProvider(create: (_) => YoutubeService()),
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
  VideoMetadata? _currentMetadata;
  bool _isLoading = false;

  Future<void> _fetchVideoInfo() async {
    setState(() => _isLoading = true);
    final ytService = Provider.of<YoutubeService>(context, listen: false);
    final meta = await ytService.getVideoInfo(_ytController.text);
    setState(() {
      _currentMetadata = meta;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final ytService = Provider.of<YoutubeService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'uMusic Project Setup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // YouTube Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'YouTube Extraction & Download',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _ytController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'YouTube URL',
                        hintText: 'Paste link here...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _fetchVideoInfo,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Fetch Info'),
                        ),
                        if (_currentMetadata != null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final muxed = await ytService.getBestMuxedStream(
                                _currentMetadata!.id,
                              );
                              if (muxed != null) {
                                downloadService.downloadYoutubeStream(
                                  muxed,
                                  '${_currentMetadata!.title}.mp4',
                                );
                              }
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Download MP4'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade100,
                            ),
                          ),
                      ],
                    ),
                    if (_currentMetadata != null) ...[
                      const SizedBox(height: 15),
                      ListTile(
                        leading: Image.network(
                          _currentMetadata!.thumbnailUrl,
                          width: 100,
                        ),
                        title: Text(
                          _currentMetadata!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Author: ${_currentMetadata!.author}\nDuration: ${_currentMetadata!.duration}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 40),

            // Active Downloads Section
            const Text(
              'Active Downloads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (downloadService.tasks.isEmpty)
              const Text(
                'No active downloads',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...downloadService.tasks.values
                  .map(
                    (task) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.file_download),
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
                            LinearProgressIndicator(value: task.progress),
                            const SizedBox(height: 8),
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
