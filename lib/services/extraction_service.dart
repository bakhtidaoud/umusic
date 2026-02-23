import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'network_service.dart';
import '../services/native_service.dart';

class YtDlpFormat {
  final String formatId;
  final String ext;
  final String? resolution;
  final String? codec;
  final double? filesizeMb;
  final String? note;
  final bool isHdr;
  final bool is360;
  final bool is3d;
  final String? url;
  final int? bitrate;
  final String? type; // 'muxed', 'video', 'audio'

  YtDlpFormat({
    required this.formatId,
    required this.ext,
    this.resolution,
    this.codec,
    this.filesizeMb,
    this.note,
    this.isHdr = false,
    this.is360 = false,
    this.is3d = false,
    this.url,
    this.bitrate,
    this.type,
  });

  factory YtDlpFormat.fromJson(Map<String, dynamic> json) {
    final note = json['format_note'] ?? '';
    final dynamicRange = json['dynamic_range'] ?? '';

    return YtDlpFormat(
      formatId: json['format_id'] ?? '',
      ext: json['ext'] ?? '',
      resolution: json['resolution'] ?? note,
      codec: json['vcodec'] != 'none' ? json['vcodec'] : json['acodec'],
      filesizeMb: (json['filesize'] != null)
          ? (json['filesize'] / 1024 / 1024)
          : null,
      note: note,
      isHdr:
          dynamicRange.toString().contains('HDR') ||
          note.toString().contains('HDR'),
      is360:
          note.toString().contains('360') ||
          json['vcodec'].toString().contains('vp9.2'),
      is3d: note.toString().contains('3D') || note.toString().contains('LR'),
      url: json['url'],
      bitrate: json['tbr'] != null
          ? (json['tbr'] * 1000).toInt()
          : json['abr'] != null
          ? (json['abr'] * 1000).toInt()
          : null,
      type: (json['vcodec'] != 'none' && json['acodec'] != 'none')
          ? 'muxed'
          : (json['vcodec'] != 'none' ? 'video' : 'audio'),
    );
  }
}

class PlaylistEntry {
  final String title;
  final String url;
  final String? videoId;
  bool isSelected;

  PlaylistEntry({
    required this.title,
    required this.url,
    this.videoId,
    this.isSelected = true,
  });
}

class UniversalMetadata {
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final List<YtDlpFormat> formats;
  final String originalUrl;
  final bool isYoutube;
  final bool isPlaylist;
  final List<PlaylistEntry> entries;
  final String? videoId;
  final String? artist;
  final String? album;

  UniversalMetadata({
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.formats,
    required this.originalUrl,
    this.isYoutube = false,
    this.isPlaylist = false,
    this.entries = const [],
    this.videoId,
    this.artist,
    this.album,
  });
}

class ExtractionService extends GetxController {
  YoutubeExplode _yt = YoutubeExplode();
  final Map<String, UniversalMetadata> _cache = {};
  String? _currentCookies;
  String? _currentProxy;

  void setCookies(String? cookies) {
    if (_currentCookies == cookies) return;
    _currentCookies = cookies;
    _yt.close();
    _yt =
        YoutubeExplode(); // In newer versions, consider passing a custom client if needed
  }

  void setProxy(String? proxy) {
    if (_currentProxy == proxy) return;
    _currentProxy = proxy;
    _yt.close();
    _yt = YoutubeExplode();
  }

  Future<UniversalMetadata?> getMetadata(String url) async {
    if (_cache.containsKey(url)) {
      debugPrint('Returning cached metadata for $url');
      return _cache[url];
    }

    if (!Get.find<NetworkService>().isConnected.value) {
      Get.snackbar(
        'Offline',
        'Cannot fetch metadata while offline.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }

    if (url.contains('youtube.com/playlist') || url.contains('list=')) {
      return _getYouTubePlaylistMetadata(url);
    } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _getYouTubeMetadata(url);
    } else {
      return _getYtDlpMetadata(url);
    }
  }

  Future<UniversalMetadata?> _getYouTubePlaylistMetadata(String url) async {
    try {
      final playlist = await _yt.playlists.get(url);
      final videos = await _yt.playlists.getVideos(playlist.id).toList();

      final entries = videos
          .map(
            (v) =>
                PlaylistEntry(title: v.title, url: v.url, videoId: v.id.value),
          )
          .toList();

      final metadata = UniversalMetadata(
        title: playlist.title,
        author: playlist.author,
        thumbnailUrl: playlist.thumbnails.highResUrl,
        formats: [],
        originalUrl: url,
        isYoutube: true,
        isPlaylist: true,
        entries: entries,
      );

      _cache[url] = metadata;
      return metadata;
    } catch (e) {
      debugPrint('YouTube playlist extraction error: $e');
      return null;
    }
  }

  Future<UniversalMetadata?> _getYouTubeMetadata(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final formats = <YtDlpFormat>[];

      for (var s in manifest.muxed) {
        formats.add(
          YtDlpFormat(
            formatId: s.tag.toString(),
            ext: s.container.name,
            resolution: s.videoQuality.toString().split('.').last,
            codec: s.videoCodec,
            filesizeMb: s.size.totalMegaBytes,
            note: 'Muxed (V+A)',
            url: s.url.toString(),
            bitrate: s.bitrate.bitsPerSecond,
            type: 'muxed',
          ),
        );
      }

      for (var s in manifest.videoOnly) {
        formats.add(
          YtDlpFormat(
            formatId: s.tag.toString(),
            ext: s.container.name,
            resolution: s.videoQuality.toString().split('.').last,
            codec: s.videoCodec,
            filesizeMb: s.size.totalMegaBytes,
            note: 'Video Only',
            url: s.url.toString(),
            bitrate: s.bitrate.bitsPerSecond,
            type: 'video',
          ),
        );
      }

      for (var s in manifest.audioOnly) {
        formats.add(
          YtDlpFormat(
            formatId: s.tag.toString(),
            ext: s.container.name,
            resolution: 'audio',
            codec: s.audioCodec,
            filesizeMb: s.size.totalMegaBytes,
            note: 'Audio Only',
            url: s.url.toString(),
            bitrate: s.bitrate.bitsPerSecond,
            type: 'audio',
          ),
        );
      }

      final metadata = UniversalMetadata(
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        formats: formats,
        originalUrl: url,
        isYoutube: true,
        videoId: video.id.value,
        artist: video.author,
        album: 'YouTube',
      );

      _cache[url] = metadata;
      return metadata;
    } catch (e) {
      debugPrint('YouTube extraction error: $e');
      return null;
    }
  }

  Future<UniversalMetadata?> _getYtDlpMetadata(String url) async {
    try {
      final result = await NativeService.runCommand('yt-dlp', [
        '-j',
        '--flat-playlist',
        url,
      ], proxy: _currentProxy);
      if (result == null || result.startsWith('Error')) return null;

      final metadata = await compute(_parseYtDlpOutput, {
        'output': result,
        'originalUrl': url,
      });

      if (metadata != null) {
        _cache[url] = metadata;
      }
      return metadata;
    } catch (e) {
      debugPrint('yt-dlp extraction error: $e');
      return null;
    }
  }

  @override
  void onClose() {
    _yt.close();
    super.onClose();
  }
}

UniversalMetadata? _parseYtDlpOutput(Map<String, dynamic> params) {
  final String result = params['output'];
  final String url = params['originalUrl'];

  try {
    final lines = result.trim().split('\n');
    if (lines.length > 1 || (jsonDecode(lines.first)['_type'] == 'playlist')) {
      final firstData = jsonDecode(lines.first);
      final title =
          firstData['title'] ??
          (firstData['_type'] == 'playlist'
              ? firstData['playlist_title']
              : 'Playlist');

      final entries = lines.map((line) {
        final entryData = jsonDecode(line);
        return PlaylistEntry(
          title: entryData['title'] ?? 'Unknown',
          url: entryData['url'] ?? entryData['webpage_url'] ?? url,
          videoId: entryData['id'],
        );
      }).toList();

      return UniversalMetadata(
        title: title,
        author: firstData['uploader'] ?? firstData['author'],
        thumbnailUrl: firstData['thumbnail'],
        formats: [],
        originalUrl: url,
        isYoutube: false,
        isPlaylist: true,
        entries: entries,
        artist: firstData['uploader'] ?? firstData['artist'],
        album: firstData['album'],
      );
    } else {
      final data = jsonDecode(lines.first);
      final rawFormats = data['formats'] as List? ?? [];
      final formats = rawFormats.map((f) => YtDlpFormat.fromJson(f)).toList();

      return UniversalMetadata(
        title: data['title'] ?? 'Unknown Title',
        author: data['uploader'] ?? data['author'],
        thumbnailUrl: data['thumbnail'],
        formats: formats,
        originalUrl: url,
        isYoutube: false,
        videoId: data['id'],
        artist: data['uploader'] ?? data['artist'],
        album: data['album'],
      );
    }
  } catch (e) {
    debugPrint('Isolate parsing error: $e');
    return null;
  }
}
