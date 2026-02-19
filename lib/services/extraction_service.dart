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

  YtDlpFormat({
    required this.formatId,
    required this.ext,
    this.resolution,
    this.codec,
    this.filesizeMb,
    this.note,
  });

  factory YtDlpFormat.fromJson(Map<String, dynamic> json) {
    return YtDlpFormat(
      formatId: json['format_id'] ?? '',
      ext: json['ext'] ?? '',
      resolution: json['resolution'] ?? json['format_note'],
      codec: json['vcodec'] != 'none' ? json['vcodec'] : json['acodec'],
      filesizeMb: (json['filesize'] != null)
          ? (json['filesize'] / 1024 / 1024)
          : null,
      note: json['format_note'],
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
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, UniversalMetadata> _cache = {};

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
      // Get JSON metadata from yt-dlp. Use --flat-playlist to detect structure quickly.
      final result = await NativeService.runCommand('yt-dlp', [
        '-j',
        '--flat-playlist',
        url,
      ]);
      if (result == null || result.startsWith('Error')) return null;

      // yt-dlp -j with --flat-playlist gives multiple JSON objects if it's a result of a search or playlist
      // But if it's a single URL, it might be one per line if it's a playlist.
      final lines = result.trim().split('\n');
      if (lines.length > 1 ||
          (jsonDecode(lines.first)['_type'] == 'playlist')) {
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

        final metadata = UniversalMetadata(
          title: title,
          author: firstData['uploader'] ?? firstData['author'],
          thumbnailUrl: firstData['thumbnail'],
          formats: [],
          originalUrl: url,
          isYoutube: false,
          isPlaylist: true,
          entries: entries,
        );

        _cache[url] = metadata;
        notifyListeners();
        return metadata;
      } else {
        // Single video
        final data = jsonDecode(lines.first);
        final rawFormats = data['formats'] as List;
        final formats = rawFormats.map((f) => YtDlpFormat.fromJson(f)).toList();

        final metadata = UniversalMetadata(
          title: data['title'] ?? 'Unknown Title',
          author: data['uploader'] ?? data['author'],
          thumbnailUrl: data['thumbnail'],
          formats: formats,
          originalUrl: url,
          isYoutube: false,
          videoId: data['id'],
        );

        _cache[url] = metadata;
        notifyListeners();
        return metadata;
      }
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
