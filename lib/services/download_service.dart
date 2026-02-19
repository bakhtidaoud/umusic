import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
  });
}

class DownloadService extends ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  final List<DownloadTask> _queue = [];
  int _activeDownloads = 0;
  int maxConcurrentDownloads = 3;
  final YoutubeExplode _yt = YoutubeExplode();

  Map<String, DownloadTask> get tasks => _tasks;

  void updateMaxConcurrent(int count) {
    maxConcurrentDownloads = count;
    _processQueue();
  }

  Future<void> runFFmpeg(List<String> args) async {
    final result = await NativeService.runCommand('ffmpeg', args);
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
    final result = await NativeService.runCommand('yt-dlp', args);
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
    final directory = await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, name);

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
    try {
      task.status = DownloadStatus.downloading;
      task.errorMessage = null;
      notifyListeners();

      // Handle Thumbnail
      if (task.downloadThumbnail && task.isYoutube && task.videoId != null) {
        await _downloadYoutubeThumbnail(task.videoId!, task.savePath);
      }

      // Handle Subtitles for YouTube
      if (task.downloadSubtitles && task.isYoutube && task.videoId != null) {
        await _downloadYoutubeSubtitles(task.videoId!, task.savePath);
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
          headers: {if (existingLength > 0) 'range': 'bytes=$existingLength-'},
        ),
        cancelToken: task.cancelToken,
      );

      final total =
          int.tryParse(response.headers.value('content-length') ?? '-1') ?? -1;
      task.totalBytes = (existingLength > 0 && total != -1)
          ? total + existingLength
          : total;

      final IOSink sink = file.openWrite(
        mode: existingLength > 0 ? FileMode.append : FileMode.write,
      );

      final Stream<Uint8List> stream = response.data.stream;

      await for (final data in stream) {
        sink.add(data);
        task.downloadedBytes += data.length;
        if (task.totalBytes != -1) {
          task.progress = task.downloadedBytes / task.totalBytes;
        }
        notifyListeners();
      }

      await sink.close();
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      notifyListeners();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        task.status = DownloadStatus.canceled;
      } else {
        task.status = DownloadStatus.error;
        task.errorMessage = e.toString();
        debugPrint('Download error: $e');
      }
      notifyListeners();
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
        final track = manifest.tracks.first; // Default to first track
        final captions = await _yt.videos.closedCaptions.get(track);
        final srtContent = _convertToSrt(captions);
        final srtPath = '${p.withoutExtension(videoPath)}.srt';
        await File(srtPath).writeAsString(srtContent);
      }
    } catch (e) {
      debugPrint('Failed to download subtitles: $e');
    }
  }

  String _convertToSrt(ClosedCaptionTrack track) {
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
}
