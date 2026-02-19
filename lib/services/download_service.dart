import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'native_service.dart';

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
  });
}

class DownloadService extends ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};

  Map<String, DownloadTask> get tasks => _tasks;

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

  Future<void> startPlatformDownload(String url, String savePath) async {
    final result = await NativeService.runCommand('yt-dlp', [
      '-o',
      savePath,
      url,
    ]);
    if (result != null && result.startsWith('Error')) {
      debugPrint("Platform download error: $result");
    }
  }

  Future<void> downloadYoutubeStream(
    StreamInfo streamInfo,
    String fileName,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, fileName);

    final task = DownloadTask(
      url: streamInfo.url.toString(),
      fileName: fileName,
      savePath: savePath,
      cancelToken: CancelToken(),
      isYoutube: true,
    );

    _tasks[task.url] = task;
    notifyListeners();
    await _startDownload(task);
  }

  Future<void> downloadFile(String url, {String? fileName}) async {
    final name = fileName ?? p.basename(Uri.parse(url).path);
    final directory = await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, name);

    if (_tasks.containsKey(url) &&
        _tasks[url]!.status == DownloadStatus.downloading) {
      return;
    }

    final task = DownloadTask(
      url: url,
      fileName: name,
      savePath: savePath,
      cancelToken: CancelToken(),
    );

    _tasks[url] = task;
    notifyListeners();

    await _startDownload(task);
  }

  Future<void> _startDownload(DownloadTask task) async {
    try {
      task.status = DownloadStatus.downloading;
      task.errorMessage = null;
      notifyListeners();

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
      if (existingLength > 0 && total != -1) {
        task.totalBytes = total + existingLength;
      } else {
        task.totalBytes = total;
      }

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
