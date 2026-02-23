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
import '../services/native_service.dart';
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
  final String? formatId;
  final String? artist;
  final String? album;
  var transferRate = 0.0.obs; // bytes per second
  var eta = Rxn<Duration>();
  var currentAction =
      'Pending'.obs; // e.g., 'Downloading', 'Muxing', 'Metadata'

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
    this.formatId,
    this.artist,
    this.album,
    double transferRate = 0.0,
    Rxn<Duration>? eta,
    String currentAction = 'Pending',
  }) {
    if (errorMessage != null) this.errorMessage = errorMessage;
    if (eta != null) this.eta = eta;
    this.status.value = status;
    this.progress.value = progress;
    this.downloadedBytes.value = downloadedBytes;
    this.totalBytes.value = totalBytes;
    this.transferRate.value = transferRate;
    this.currentAction.value = currentAction;
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
    String? formatId,
    String? artist,
    String? album,
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
      formatId: formatId,
      artist: artist,
      album: album,
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

        String downloadUrl = task.url;

        // Specialized Download logic for YouTube via yt-dlp if format is specified
        if (task.isYoutube && task.formatId != null) {
          await _downloadWithYtDlp(task);
          return;
        }

        if (task.isYoutube && task.formatId == null) {
          try {
            final vid = task.videoId ?? VideoId(task.url).value;
            final manifest = await _yt.videos.streamsClient.getManifest(vid);
            final streamInfo = manifest.muxed.withHighestBitrate();
            downloadUrl = streamInfo.url.toString();
          } catch (e) {
            debugPrint('Error resolving YouTube stream for download: $e');
            throw Exception("Could not resolve YouTube stream: $e");
          }
        }

        task.currentAction.value = 'Downloading';
        final response = await _dio.get(
          downloadUrl,
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

        // Apply Metadata if it's an audio file
        if (task.artist != null || task.downloadThumbnail) {
          await _applyMetadata(task);
        }

        task.status.value = DownloadStatus.completed;
        task.progress.value = 1.0;
        task.transferRate.value = 0;
        task.eta.value = null;
        task.currentAction.value = 'Completed';

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

  Future<void> _downloadWithYtDlp(DownloadTask task) async {
    try {
      task.currentAction.value = 'Preparing';
      final List<String> args = [
        '-f',
        task.formatId!,
        '--no-part',
        '--newline',
        '-o',
        task.savePath,
        task.url,
      ];

      _sendNotification(
        task.url.hashCode,
        'uMusic: Downloading',
        'Processing ${task.fileName}...',
      );

      final result = await NativeService.runCommand(
        'yt-dlp',
        args,
        proxy: _proxy,
      );
      if (result != null && result.startsWith('Error')) {
        throw Exception(result);
      }

      // Metadata for yt-dlp downloads
      if (task.artist != null || task.downloadThumbnail) {
        await _applyMetadata(task);
      }

      task.status.value = DownloadStatus.completed;
      task.progress.value = 1.0;
      task.currentAction.value = 'Completed';
      _activeDownloads--;
      _processQueue();
    } catch (e) {
      task.status.value = DownloadStatus.error;
      task.errorMessage.value = e.toString();
      _activeDownloads--;
      _processQueue();
    }
  }

  Future<void> _applyMetadata(DownloadTask task) async {
    task.currentAction.value = 'Applying Metadata';
    try {
      final ext = p.extension(task.savePath).toLowerCase();
      final thumbPath = task.savePath.replaceAll(ext, '.jpg');

      if (task.downloadThumbnail && task.videoId != null) {
        await _downloadThumbnailInternal(task);
      }

      if (['.mp4', '.mkv', '.mp3', '.m4a', '.opus', '.webm'].contains(ext)) {
        final tempPath = '${task.savePath}.meta$ext';
        final List<String> args = ['-i', task.savePath];

        if (File(thumbPath).existsSync()) {
          args.addAll(['-i', thumbPath, '-map', '0', '-map', '1']);
          if (ext == '.mp3') {
            args.addAll([
              '-c:a',
              'copy',
              '-c:v',
              'copy',
              '-id3v2_version',
              '3',
              '-metadata:s:v',
              'title="Album cover"',
              '-metadata:s:v',
              'comment="Cover (Front)"',
            ]);
          } else {
            args.addAll(['-c', 'copy', '-disposition:v:0', 'attached_pic']);
          }
        } else {
          args.addAll(['-c', 'copy']);
        }

        if (task.artist != null)
          args.addAll(['-metadata', 'artist=${task.artist}']);
        if (task.album != null)
          args.addAll(['-metadata', 'album=${task.album}']);
        args.add(tempPath);

        final result = await NativeService.runCommand('ffmpeg', args);
        if (result != null && !result.startsWith('Error')) {
          final original = File(task.savePath);
          final temp = File(tempPath);
          await original.delete();
          await temp.rename(task.savePath);
        }
      }
    } catch (e) {
      debugPrint('Metadata error: $e');
    }
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
