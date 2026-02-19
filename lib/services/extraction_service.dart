import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'native_service.dart';

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
  });
}

class ExtractionService extends ChangeNotifier {
  YoutubeExplode _yt = YoutubeExplode();
  final Map<String, UniversalMetadata> _cache = {};
  String? _currentCookies;

  void setCookies(String? cookies) {
    if (_currentCookies == cookies) return;
    _currentCookies = cookies;
    _yt.close();

    // For youtube_explode_dart, we'll use the default client for now
    // as constructor injection varies by package version.
    _yt = YoutubeExplode();
    notifyListeners();
  }

  String? _currentProxy;

  void setProxy(String? proxy) {
    if (_currentProxy == proxy) return;
    _currentProxy = proxy;
    _yt.close();
    _yt = YoutubeExplode();
    notifyListeners();
  }

  Future<UniversalMetadata?> getMetadata(String url) async {
    if (_cache.containsKey(url)) {
      debugPrint('Returning cached metadata for $url');
      return _cache[url];
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
      notifyListeners();
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

      // Combine muxed and separate streams into a unified format list
      for (var s in manifest.muxed) {
        formats.add(
          YtDlpFormat(
            formatId: s.tag.toString(),
            ext: s.container.name,
            resolution: s.videoQuality.toString().split('.').last,
            codec: s.videoCodec,
            filesizeMb: s.size.totalMegaBytes,
            note: 'Muxed (V+A)',
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
      );

      _cache[url] = metadata;
      notifyListeners();
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

      // Use compute to parse large JSON strings in a separate isolate
      final metadata = await compute(_parseYtDlpOutput, {
        'output': result,
        'originalUrl': url,
      });

      if (metadata != null) {
        _cache[url] = metadata;
        notifyListeners();
      }
      return metadata;
    } catch (e) {
      debugPrint('yt-dlp extraction error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}

/// Top-level function for isolate-based parsing
UniversalMetadata? _parseYtDlpOutput(Map<String, dynamic> params) {
  final String result = params['output'];
  final String url = params['originalUrl'];

  try {
    final lines = result.trim().split('\n');
    if (lines.length > 1 || (jsonDecode(lines.first)['_type'] == 'playlist')) {
      // Handle as playlist
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
      );
    } else {
      // Single video
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
      );
    }
  } catch (e) {
    debugPrint('Isolate parsing error: $e');
    return null;
  }
}
