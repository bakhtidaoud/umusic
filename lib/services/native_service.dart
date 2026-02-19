import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NativeService {
  static const _platform = MethodChannel('downloader_channel');

  /// Ensures yt-dlp and ffmpeg are available on desktop.
  /// On mobile, this assumes they are handled by the platform channel.
  static Future<void> initializeBinaries() async {
    if (kIsWeb) return;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final binDir = await _getBinDirectory();
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final ytdlpName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';

      await _extractAsset(
        'assets/binaries/$ffmpegName',
        p.join(binDir.path, ffmpegName),
      );
      await _extractAsset(
        'assets/binaries/$ytdlpName',
        p.join(binDir.path, ytdlpName),
      );

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', p.join(binDir.path, ffmpegName)]);
        await Process.run('chmod', ['+x', p.join(binDir.path, ytdlpName)]);
      }
    }
  }

  static Future<Directory> _getBinDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, 'bin'));
  }

  static Future<void> _extractAsset(String assetPath, String outputPath) async {
    final file = File(outputPath);
    if (await file.exists()) return;

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Failed to extract asset $assetPath: $e');
    }
  }

  static Future<String?> runCommand(String command, List<String> args) async {
    final cookieFile = File(
      p.join((await getApplicationSupportDirectory()).path, 'cookies.txt'),
    );
    final List<String> finalArgs = List.from(args);

    if (command == 'yt-dlp' && await cookieFile.exists()) {
      finalArgs.insert(0, '--cookies');
      finalArgs.insert(1, cookieFile.path);
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (command == 'ffmpeg') {
          return await _platform.invokeMethod('runFFmpeg', {'args': args});
        } else if (command == 'yt-dlp') {
          // Assuming a generic startDownload or similar for yt-dlp on mobile
          return await _platform.invokeMethod('startDownload', {
            'url': args.last,
            'args': args,
          });
        }
      } on PlatformException catch (e) {
        return 'Error: ${e.message}';
      }
    } else {
      // Desktop logic
      final binDir = await _getBinDirectory();
      final exeName = Platform.isWindows ? '$command.exe' : command;
      final exePath = p.join(binDir.path, exeName);

      if (!await File(exePath).exists()) {
        return 'Error: Binary $command not found at $exePath';
      }

      final result = await Process.run(exePath, args);
      if (result.exitCode == 0) {
        return result.stdout.toString();
      } else {
        return 'Error: ${result.stderr}';
      }
    }
    return null;
  }
}
