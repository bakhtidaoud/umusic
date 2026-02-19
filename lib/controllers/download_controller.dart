import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/extraction_service.dart';
import 'library_controller.dart';

enum DownloadStatus { pending, downloading, paused, completed, canceled, error }

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  var status = DownloadStatus.pending.obs;
  var progress = 0.0.obs;
  var downloadedBytes = 0.obs;
  var totalBytes = (-1).obs;
  CancelToken? cancelToken;
  var errorMessage = RxnString();
  final bool isYoutube;
  final bool downloadSubtitles;
  final bool downloadThumbnail;
  final String? videoId;
  var transferRate = 0.0.obs; // bytes per second
  var eta = Rxn<Duration>();

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    DownloadStatus status = DownloadStatus.pending,
    double progress = 0.0,
    int downloadedBytes = 0,
    int totalBytes = -1,
    this.cancelToken,
    RxnString? errorMessage,
    this.isYoutube = false,
    this.downloadSubtitles = false,
    this.downloadThumbnail = false,
    this.videoId,
    double transferRate = 0.0,
    Rxn<Duration>? eta,
  }) {
    if (errorMessage != null) this.errorMessage = errorMessage;
    if (eta != null) this.eta = eta;
    this.status.value = status;
    this.progress.value = progress;
    this.downloadedBytes.value = downloadedBytes;
    this.totalBytes.value = totalBytes;
    this.transferRate.value = transferRate;
  }
}

class DownloadController extends GetxController {
  final Dio _dio = Dio();
  final RxMap<String, DownloadTask> tasks = <String, DownloadTask>{}.obs;
  final RxList<DownloadTask> _queue = <DownloadTask>[].obs;
  int _activeDownloads = 0;
  var maxConcurrentDownloads = 3.obs;
  String? _proxy;
  final YoutubeExplode _yt = YoutubeExplode();

  String? _downloadFolder;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void onInit() {
    super.onInit();
    _setupDio();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings: initSettings);
  }

  void updateDownloadFolder(String? path) {
    _downloadFolder = path;
  }

  void updateMaxConcurrent(int count) {
    maxConcurrentDownloads.value = count;
  }

  void _setupDio() {
    if (_proxy != null && _proxy!.isNotEmpty) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) {
            return "PROXY $_proxy";
          };
          return client;
        },
      );
    } else {
      _dio.httpClientAdapter = IOHttpClientAdapter();
    }
  }

  void updateProxy(String? proxy) {
    if (_proxy == proxy) return;
    _proxy = proxy;
    _setupDio();
  }

  Future<void> downloadFile(
    String url, {
    String? fileName,
    bool isYoutube = false,
    bool downloadSubtitles = false,
    bool downloadThumbnail = false,
    String? videoId,
  }) async {
    if (tasks.containsKey(url)) return;

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

    final task = DownloadTask(
      url: url,
      fileName: name,
      savePath: savePath,
      isYoutube: isYoutube,
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
      videoId: videoId,
    );

    tasks[url] = task;
    _queue.add(task);
    _processQueue();
  }

  Future<void> downloadBatch(List<PlaylistEntry> entries) async {
    for (var entry in entries.where((e) => e.isSelected)) {
      await downloadFile(
        entry.url,
        fileName: '${entry.title}.mp4', // Default ext
        isYoutube: true,
        videoId: entry.videoId,
      );
    }
  }

  void _processQueue() {
    while (_activeDownloads < maxConcurrentDownloads.value &&
        _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _activeDownloads++;
      _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    int retries = 0;
    const maxRetries = 2;

    while (retries <= maxRetries) {
      try {
        if (Platform.isAndroid) {
          if (!await Permission.storage.request().isGranted) {
            task.status.value = DownloadStatus.error;
            task.errorMessage.value = "Storage permission denied";
            _activeDownloads--;
            _processQueue();
            return;
          }
          if (await Permission.notification.isDenied) {
            await Permission.notification.request();
          }
        }

        task.status.value = DownloadStatus.downloading;
        task.errorMessage.value = null;

        _sendNotification(
          task.url.hashCode,
          'uMusic: Downloading',
          'Starting ${task.fileName}...',
        );

        if (retries == 0) {
          if (task.downloadThumbnail && task.videoId != null) {
            _downloadThumbnailInternal(task);
          }
          if (task.downloadSubtitles && task.videoId != null) {
            _downloadSubtitlesInternal(task);
          }
        }

        task.cancelToken = CancelToken();
        int lastDownloaded = 0;
        DateTime lastUpdateTime = DateTime.now();

        final response = await _dio.get(
          task.url,
          options: Options(responseType: ResponseType.stream),
          cancelToken: task.cancelToken,
        );

        final file = File(task.savePath);
        final sink = file.openWrite();
        task.totalBytes.value =
            int.tryParse(response.headers.value('content-length') ?? '-1') ??
            -1;

        await for (final chunk in response.data.stream) {
          sink.add(chunk);
          task.downloadedBytes.value += chunk.length as int;

          final now = DateTime.now();
          final elapsed = now.difference(lastUpdateTime).inMilliseconds;

          if (elapsed > 500) {
            final bytesInInterval = task.downloadedBytes.value - lastDownloaded;
            task.transferRate.value = (bytesInInterval / (elapsed / 1000.0));

            if (task.totalBytes.value != -1) {
              task.progress.value =
                  task.downloadedBytes.value / task.totalBytes.value;
              final remainingBytes =
                  task.totalBytes.value - task.downloadedBytes.value;
              if (task.transferRate.value > 0) {
                task.eta.value = Duration(
                  seconds: (remainingBytes / task.transferRate.value).toInt(),
                );
              }

              if ((task.progress.value * 100).toInt() % 5 == 0) {
                _sendNotification(
                  task.url.hashCode,
                  'uMusic: Downloading',
                  '${task.fileName}: ${(task.progress.value * 100).toStringAsFixed(0)}%',
                  progress: (task.progress.value * 100).toInt(),
                );
              }
            }

            lastDownloaded = task.downloadedBytes.value;
            lastUpdateTime = now;
          }
        }

        await sink.close();
        task.status.value = DownloadStatus.completed;
        task.progress.value = 1.0;
        task.transferRate.value = 0;
        task.eta.value = null;

        _sendNotification(
          task.url.hashCode,
          'uMusic: Finished',
          'Successfully downloaded ${task.fileName}',
          completed: true,
        );

        _activeDownloads--;

        // Refresh library if controller exists
        if (Get.isRegistered<LibraryController>()) {
          Get.find<LibraryController>().scanFiles();
        }

        _processQueue();
        return;
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) {
          task.status.value = DownloadStatus.canceled;
          _activeDownloads--;
          _processQueue();
          return;
        }

        retries++;
        if (retries > maxRetries) {
          task.status.value = DownloadStatus.error;
          task.errorMessage.value = e.toString();
          _sendNotification(
            task.url.hashCode,
            'uMusic: Failed',
            'Error downloading ${task.fileName}',
          );
          _activeDownloads--;
          _processQueue();
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _downloadThumbnailInternal(DownloadTask task) async {
    try {
      final video = await _yt.videos.get(task.videoId!);
      final thumbUrl = video.thumbnails.highResUrl;
      final response = await _dio.get(
        thumbUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final thumbFile = File(
        task.savePath.replaceAll(p.extension(task.savePath), '.jpg'),
      );
      await thumbFile.writeAsBytes(response.data);
    } catch (e) {
      debugPrint('Thumbnail download error: $e');
    }
  }

  Future<void> _downloadSubtitlesInternal(DownloadTask task) async {
    try {
      final manifest = await _yt.videos.closedCaptions.getManifest(
        task.videoId!,
      );
      if (manifest.tracks.isNotEmpty) {
        final track = manifest.tracks.first;
        final content = await _yt.videos.closedCaptions.get(track);
        final srtContent = await compute(_convertToSrtIsolate, content);
        final subFile = File(
          task.savePath.replaceAll(p.extension(task.savePath), '.srt'),
        );
        await subFile.writeAsString(srtContent);
      }
    } catch (e) {
      debugPrint('Subtitles download error: $e');
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

  void cancelDownload(String url) {
    final task = tasks[url];
    if (task != null) {
      task.cancelToken?.cancel('canceled');
      task.status.value = DownloadStatus.canceled;
      tasks.remove(url);
    }
  }

  void pauseDownload(String url) {
    final task = tasks[url];
    if (task != null && task.status.value == DownloadStatus.downloading) {
      task.cancelToken?.cancel('paused');
      task.status.value = DownloadStatus.paused;
      _activeDownloads--;
      _processQueue();
    }
  }

  Future<void> resumeDownload(String url) async {
    final task = tasks[url];
    if (task != null && task.status.value == DownloadStatus.paused) {
      _queue.insert(0, task);
      _processQueue();
    }
  }

  @override
  void onClose() {
    _yt.close();
    super.onClose();
  }
}

String _convertToSrtIsolate(ClosedCaptionTrack track) {
  var buffer = StringBuffer();
  for (var i = 0; i < track.captions.length; i++) {
    final caption = track.captions[i];
    buffer.writeln('${i + 1}');
    buffer.writeln(
      '${_formatDuration(caption.offset)} --> ${_formatDuration(caption.offset + caption.duration)}',
    );
    buffer.writeln(caption.text);
    buffer.writeln();
  }
  return buffer.toString();
}

String _formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String threeDigits(int n) => n.toString().padLeft(3, "0");
  final hours = twoDigits(d.inHours);
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  final milliseconds = threeDigits(d.inMilliseconds.remainder(1000));
  return "$hours:$minutes:$seconds,$milliseconds";
}
