import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'config_controller.dart';

class LocalFile {
  final String path;
  final String name;
  final String extension;
  final DateTime modified;
  final String? thumbnailPath;
  final int size;

  LocalFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.modified,
    this.thumbnailPath,
    required this.size,
  });
}

class LibraryController extends GetxController {
  var allFiles = <LocalFile>[].obs;
  var filteredFiles = <LocalFile>[].obs;
  var isLoading = false.obs;

  final String _thumbnailSubDir = 'library_thumbnails';

  @override
  void onInit() {
    super.onInit();
    scanFiles();
  }

  Future<void> scanFiles() async {
    isLoading.value = true;
    try {
      final config = Get.find<ConfigController>().config;
      String? dirPath = config.downloadFolder;

      if (dirPath == null) {
        if (Platform.isAndroid) {
          dirPath = '/storage/emulated/0/Download';
        } else {
          final directory = await getApplicationDocumentsDirectory();
          dirPath = directory.path;
        }
      }

      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        allFiles.value = [];
        filteredFiles.value = [];
        return;
      }

      final List<FileSystemEntity> entities = await dir.list().toList();
      final List<LocalFile> files = [];

      final supportDir = await getApplicationSupportDirectory();
      final thumbDir = Directory(p.join(supportDir.path, _thumbnailSubDir));
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      for (var entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (['.mp4', '.mkv', '.webm', '.mp3', '.m4a', '.wav'].contains(ext)) {
            final stat = await entity.stat();
            String? thumbPath;

            if (['.mp4', '.mkv', '.webm'].contains(ext)) {
              thumbPath = await _getOrCreateThumbnail(
                entity.path,
                thumbDir.path,
              );
            }

            files.add(
              LocalFile(
                path: entity.path,
                name: p.basename(entity.path),
                extension: ext,
                modified: stat.modified,
                size: stat.size,
                thumbnailPath: thumbPath,
              ),
            );
          }
        }
      }

      // Sort by modified date descending
      files.sort((a, b) => b.modified.compareTo(a.modified));

      allFiles.value = files;
      filteredFiles.value = files;
    } catch (e) {
      Get.snackbar('Error', 'Failed to scan library: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _getOrCreateThumbnail(
    String videoPath,
    String thumbDirPath,
  ) async {
    try {
      final fileName = p.basenameWithoutExtension(videoPath);
      final thumbPath = p.join(thumbDirPath, '$fileName.jpg');

      if (await File(thumbPath).exists()) return thumbPath;

      final result = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbDirPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 75,
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      filteredFiles.value = allFiles;
    } else {
      filteredFiles.value = allFiles
          .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> deleteFile(LocalFile file) async {
    try {
      final f = File(file.path);
      if (await f.exists()) await f.delete();

      if (file.thumbnailPath != null) {
        final t = File(file.thumbnailPath!);
        if (await t.exists()) await t.delete();
      }

      allFiles.removeWhere((element) => element.path == file.path);
      filteredFiles.removeWhere((element) => element.path == file.path);

      Get.snackbar('Success', 'File deleted from storage');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete file: $e');
    }
  }
}
