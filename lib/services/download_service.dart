import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_service.dart';
import 'extraction_service.dart';

enum DownloadStatus { pending, downloading, paused, completed, canceled, error }

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  CancelToken? cancelToken;
  String? errorMessage;
  final bool isYoutube;
  final bool downloadSubtitles;
  final bool downloadThumbnail;
  final String? videoId;
  double transferRate; // bytes per second
  Duration? eta;

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    this.cancelToken,
    this.errorMessage,
    this.isYoutube = false,
    this.downloadSubtitles = false,
    this.downloadThumbnail = false,
    this.videoId,
    this.transferRate = 0,
    this.eta,
  });
}

class DownloadService extends ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  final List<DownloadTask> _queue = [];
  int _activeDownloads = 0;
  int maxConcurrentDownloads = 3;
  String? _proxy;
  final YoutubeExplode _yt = YoutubeExplode();

  String? _downloadFolder;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  DownloadService() {
    _setupDio();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
  }

  void updateDownloadFolder(String? path) {
    _downloadFolder = path;
  }

  void _setupDio() {
    if (_proxy != null && _proxy!.isNotEmpty) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return "PROXY $_proxy";
          };
          // For SOCKS, you might need a different approach depending on the platform,
          // but "PROXY host:port" covers standard HTTP proxies.
          // Note: Dart's HttpClient findProxy expects "PROXY <host>:<port>" or "DIRECT"
          return client;
        },
      );
    } else {
      _dio.httpClientAdapter = IOHttpClientAdapter();
    }
  }

  void updateProxy(String? proxy) {
    _proxy = proxy;
    _setupDio();
  }

  Map<String, DownloadTask> get tasks => _tasks;

  void updateMaxConcurrent(int count) {
    maxConcurrentDownloads = count;
    _processQueue();
  }

  Future<void> runFFmpeg(List<String> args) async {
    final result = await NativeService.runCommand(
      'ffmpeg',
      args,
      proxy: _proxy,
    );
    if (result != null && result.startsWith('Error')) {
      debugPrint("FFmpeg error: $result");
    }
  }

  Future<void> mergeFiles(
    String videoPath,
    String audioPath,
    String outputPath,
  ) async {
    await runFFmpeg([
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-c',
      'copy',
      outputPath,
    ]);
  }

  Future<void> startPlatformDownload(
    String url,
    String savePath, {
    bool downloadSubtitles = false,
    bool downloadThumbnail = false,
  }) async {
    final args = [
      '-o',
      savePath,
      if (downloadSubtitles) ...[
        '--write-subs',
        '--write-auto-subs',
        '--convert-subs',
        'srt',
      ],
      if (downloadThumbnail) '--write-thumbnail',
      url,
    ];
    final result = await NativeService.runCommand(
      'yt-dlp',
      args,
      proxy: _proxy,
    );
    if (result != null && result.startsWith('Error')) {
      debugPrint("Platform download error: $result");
    }
  }

  Future<void> downloadBatch(List<PlaylistEntry> entries) async {
    for (var entry in entries) {
      if (entry.isSelected) {
        // Here we just queue them. For now, we assume direct download for simplicity
        // In a real app, you'd fetch the best format for each first.
        downloadFile(entry.url, fileName: '${entry.title}.mp4');
      }
    }
  }

  Future<void> downloadYoutubeStream(
    StreamInfo streamInfo,
    String fileName,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, fileName);

    if (_tasks.containsKey(streamInfo.url.toString())) return;

    final task = DownloadTask(
      url: streamInfo.url.toString(),
      fileName: fileName,
      savePath: savePath,
      cancelToken: CancelToken(),
      isYoutube: true,
    );

    _tasks[task.url] = task;
    _queue.add(task);
    notifyListeners();

    _processQueue();
  }

  Future<void> downloadFile(
    String url, {
    String? fileName,
    bool downloadSubtitles = false,
    bool downloadThumbnail = false,
    String? videoId,
    bool isYoutube = false,
  }) async {
    final name = fileName ?? p.basename(Uri.parse(url).path);
    String dirPath;
    if (_downloadFolder != null) {
      dirPath = _downloadFolder!;
    } else {
      if (Platform.isAndroid) {
        dirPath = '/storage/emulated/0/Download';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        dirPath = directory.path;
      }
    }
    final savePath = p.join(dirPath, name);

    if (_tasks.containsKey(url)) return;

    final task = DownloadTask(
      url: url,
      fileName: name,
      savePath: savePath,
      cancelToken: CancelToken(),
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
      videoId: videoId,
      isYoutube: isYoutube,
    );

    _tasks[url] = task;
    _queue.add(task);
    notifyListeners();

    _processQueue();
  }

  void _processQueue() {
    while (_activeDownloads < maxConcurrentDownloads && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _activeDownloads++;
      _startDownload(task)
          .then((_) {
            _activeDownloads--;
            _processQueue();
          })
          .catchError((e) {
            debugPrint('Error in _processQueue for task ${task.url}: $e');
            task.status = DownloadStatus.error;
            task.errorMessage = e.toString();
            notifyListeners();
            _activeDownloads--;
            _processQueue();
          });
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    int retries = 0;
    const int maxRetries = 5;

    while (retries <= maxRetries) {
      try {
        if (Platform.isAndroid) {
          if (!await Permission.storage.request().isGranted) {
            task.status = DownloadStatus.error;
            task.errorMessage = "Storage permission denied";
            notifyListeners();
            return;
          }
          if (await Permission.notification.isDenied) {
            await Permission.notification.request();
          }
        }

        task.status = DownloadStatus.downloading;
        task.errorMessage = null;
        notifyListeners();

        _sendNotification(
          task.url.hashCode,
          'uMusic: Downloading',
          'Starting ${task.fileName}...',
        );

        // Handle Thumbnail & Subtitles (only on first attempt)
        if (retries == 0) {
          if (task.downloadThumbnail &&
              task.isYoutube &&
              task.videoId != null) {
            await _downloadYoutubeThumbnail(task.videoId!, task.savePath);
          }
          if (task.downloadSubtitles &&
              task.isYoutube &&
              task.videoId != null) {
            await _downloadYoutubeSubtitles(task.videoId!, task.savePath);
          }
        }

        File file = File(task.savePath);
        int existingLength = 0;
        if (await file.exists()) {
          existingLength = await file.length();
        }

        task.downloadedBytes = existingLength;

        Response response = await _dio.get(
          task.url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              if (existingLength > 0) 'range': 'bytes=$existingLength-',
            },
          ),
          cancelToken: task.cancelToken,
        );

        final total =
            int.tryParse(response.headers.value('content-length') ?? '-1') ??
            -1;
        task.totalBytes = (existingLength > 0 && total != -1)
            ? total + existingLength
            : total;

        final IOSink sink = file.openWrite(
          mode: existingLength > 0 ? FileMode.append : FileMode.write,
        );

        final Stream<Uint8List> stream = response.data.stream;
        int lastBytes = task.downloadedBytes;
        DateTime lastTime = DateTime.now();

        await for (final data in stream) {
          sink.add(data);
          task.downloadedBytes += data.length;

          final now = DateTime.now();
          final diffMs = now.difference(lastTime).inMilliseconds;
          if (diffMs >= 1000) {
            final diffBytes = task.downloadedBytes - lastBytes;
            task.transferRate = (diffBytes / diffMs) * 1000;
            if (task.totalBytes != -1) {
              final remaining = task.totalBytes - task.downloadedBytes;
              if (task.transferRate > 0) {
                task.eta = Duration(
                  seconds: (remaining / task.transferRate).floor(),
                );
              }
            }
            lastBytes = task.downloadedBytes;
            lastTime = now;
          }

          if (task.totalBytes != -1) {
            task.progress = task.downloadedBytes / task.totalBytes;

            // Update notification every few percent to avoid spamming
            if ((task.progress * 100).toInt() % 5 == 0) {
              _sendNotification(
                task.url.hashCode,
                'uMusic: Downloading',
                '${task.fileName}: ${(task.progress * 100).toStringAsFixed(0)}%',
                progress: (task.progress * 100).toInt(),
              );
            }
          }
          notifyListeners();
        }

        await sink.close();
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.transferRate = 0;
        task.eta = null;

        _sendNotification(
          task.url.hashCode,
          'uMusic: Finished',
          'Successfully downloaded ${task.fileName}',
          completed: true,
        );

        notifyListeners();
        return; // Success, exit loop
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) {
          task.status = DownloadStatus.canceled;
          notifyListeners();
          return;
        }

        retries++;
        if (retries > maxRetries) {
          task.status = DownloadStatus.error;
          task.errorMessage = e.toString();
          debugPrint('Download error (fatal): $e');

          _sendNotification(
            task.url.hashCode,
            'uMusic: Failed',
            'Error downloading ${task.fileName}',
          );

          notifyListeners();
          return;
        }

        // Exponential backoff: 2^retries * 1000ms
        final delay = Duration(milliseconds: (retries * retries * 1000));
        debugPrint(
          'Download error: $e. Retrying in ${delay.inSeconds}s... ($retries/$maxRetries)',
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _downloadYoutubeThumbnail(
    String videoId,
    String videoPath,
  ) async {
    try {
      final thumbUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      final thumbPath = '${p.withoutExtension(videoPath)}.jpg';
      await _dio.download(thumbUrl, thumbPath);
    } catch (e) {
      debugPrint('Failed to download thumbnail: $e');
    }
  }

  Future<void> _downloadYoutubeSubtitles(
    String videoId,
    String videoPath,
  ) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isNotEmpty) {
        final track = manifest.tracks.first;
        final captions = await _yt.videos.closedCaptions.get(track);

        // Move SRT conversion to an isolate
        final srtContent = await compute(_convertToSrtIsolate, captions);

        final srtPath = '${p.withoutExtension(videoPath)}.srt';
        await File(srtPath).writeAsString(srtContent);
      }
    } catch (e) {
      debugPrint('Failed to download subtitles: $e');
    }
  }

  void pauseDownload(String url) {
    final task = _tasks[url];
    if (task != null && task.status == DownloadStatus.downloading) {
      task.cancelToken?.cancel('paused');
      task.status = DownloadStatus.paused;
      task.cancelToken = CancelToken();
      notifyListeners();
    }
  }

  Future<void> resumeDownload(String url) async {
    final task = _tasks[url];
    if (task != null && task.status == DownloadStatus.paused) {
      await _startDownload(task);
    }
  }

  void cancelDownload(String url) {
    final task = _tasks[url];
    if (task != null) {
      task.cancelToken?.cancel('canceled');
      task.status = DownloadStatus.canceled;
      _tasks.remove(url);
      notifyListeners();
    }
  }

  void openFileFolder(String url) {
    final task = _tasks[url];
    if (task != null) {
      NativeService.openFolder(task.savePath);
    }
  }

  Future<void> _sendNotification(
    int id,
    String title,
    String body, {
    bool completed = false,
    int progress = 0,
    int maxProgress = 100,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel_id',
      'Download Notifications',
      channelDescription: 'Showing download progress and completion',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      onlyAlertOnce: !completed,
      showProgress: !completed,
      maxProgress: maxProgress,
      progress: progress,
    );
    final details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}

/// Top-level function for SRT conversion in isolate
String _convertToSrtIsolate(ClosedCaptionTrack track) {
  var buffer = StringBuffer();
  for (var i = 0; i < track.captions.length; i++) {
    final caption = track.captions[i];
    buffer.writeln('${i + 1}');
    buffer.writeln(
      '${_formatDurationIsolate(caption.offset)} --> ${_formatDurationIsolate(caption.offset + caption.duration)}',
    );
    buffer.writeln(caption.text);
    buffer.writeln();
  }
  return buffer.toString();
}

String _formatDurationIsolate(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String threeDigits(int n) => n.toString().padLeft(3, "0");
  final hours = twoDigits(d.inHours);
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  final milliseconds = threeDigits(d.inMilliseconds.remainder(1000));
  return "$hours:$minutes:$seconds,$milliseconds";
}
