import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_metadata.dart';

class YoutubeService extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<VideoMetadata?> getVideoInfo(String url) async {
    try {
      // Get video metadata
      final video = await _yt.videos.get(url);

      // Get manifest for streams
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final videoStreams = manifest.video
          .map(
            (s) => AppVideoStreamInfo(
              tag: s.tag.toString(),
              codec: s.codec.toString(),
              quality: s.videoQuality
                  .toString()
                  .split('.')
                  .last, // Fallback for quality label
              sizeInMb: s.size.totalMegaBytes,
            ),
          )
          .toList();

      final audioStreams = manifest.audio
          .map(
            (s) => AppAudioStreamInfo(
              tag: s.tag.toString(),
              codec: s.codec.toString(),
              sizeInMb: s.size.totalMegaBytes,
            ),
          )
          .toList();

      // Get subtitles
      final captionManifest = await _yt.videos.closedCaptions.getManifest(
        video.id,
      );
      final subtitles = captionManifest.tracks.toList();

      final thumbnailsList = <Thumbnail>[
        video.thumbnails.lowResUrl.isNotEmpty
            ? Thumbnail(Uri.parse(video.thumbnails.lowResUrl), 120, 90)
            : null,
        video.thumbnails.mediumResUrl.isNotEmpty
            ? Thumbnail(Uri.parse(video.thumbnails.mediumResUrl), 320, 180)
            : null,
        video.thumbnails.highResUrl.isNotEmpty
            ? Thumbnail(Uri.parse(video.thumbnails.highResUrl), 480, 360)
            : null,
        video.thumbnails.standardResUrl.isNotEmpty
            ? Thumbnail(Uri.parse(video.thumbnails.standardResUrl), 640, 480)
            : null,
        video.thumbnails.maxResUrl.isNotEmpty
            ? Thumbnail(Uri.parse(video.thumbnails.maxResUrl), 1280, 720)
            : null,
      ].whereType<Thumbnail>().toList();

      final metadata = VideoMetadata(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.highResUrl,
        thumbnails: thumbnailsList,
        videoStreams: videoStreams,
        audioStreams: audioStreams,
        subtitles: subtitles,
      );

      // Print to console as requested
      debugPrint('--- Video Info ---');
      debugPrint('Title: ${metadata.title}');
      debugPrint('Author: ${metadata.author}');
      debugPrint('Duration: ${metadata.duration}');
      debugPrint('Thumbnails: ${metadata.thumbnailUrl}');
      debugPrint('Video Streams: ${metadata.videoStreams.length}');
      for (var s in metadata.videoStreams) {
        debugPrint(
          '  - ${s.quality} [${s.codec}] (${s.sizeInMb.toStringAsFixed(2)} MB)',
        );
      }
      debugPrint('Audio Streams: ${metadata.audioStreams.length}');
      for (var s in metadata.audioStreams) {
        debugPrint('  - ${s.codec} (${s.sizeInMb.toStringAsFixed(2)} MB)');
      }
      debugPrint('Subtitles: ${metadata.subtitles.length}');
      for (var t in metadata.subtitles) {
        debugPrint('  - ${t.language.name} (${t.language.code})');
      }
      debugPrint('------------------');

      return metadata;
    } catch (e) {
      debugPrint('Error getting video info: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
