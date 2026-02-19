import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';
import 'package:flutter/material.dart';

import 'services/download_service.dart';
import 'services/youtube_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

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
  final String _sampleUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final task = downloadService.tasks[_sampleUrl];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'uMusic Download Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (task == null)
              ElevatedButton.icon(
                onPressed: () => downloadService.downloadFile(_sampleUrl),
                icon: const Icon(Icons.download),
                label: const Text('Start Download'),
              )
            else ...[
              Text('File: ${task.fileName}'),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: task.progress),
              const SizedBox(height: 10),
              Text(
                'Status: ${task.status.name.toUpperCase()} (${(task.progress * 100).toStringAsFixed(1)}%)',
              ),
              if (task.errorMessage != null)
                Text(
                  'Error: ${task.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (task.status == DownloadStatus.downloading)
                    IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: () =>
                          downloadService.pauseDownload(_sampleUrl),
                    )
                  else if (task.status == DownloadStatus.paused)
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () =>
                          downloadService.resumeDownload(_sampleUrl),
                    ),
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => downloadService.cancelDownload(_sampleUrl),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
