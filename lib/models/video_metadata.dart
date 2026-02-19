import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoMetadata {
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;
  final List<Thumbnail> thumbnails;
  final List<AppVideoStreamInfo> videoStreams;
  final List<AppAudioStreamInfo> audioStreams;
  final List<ClosedCaptionTrackInfo> subtitles;

  VideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
    required this.thumbnails,
    required this.videoStreams,
    required this.audioStreams,
    required this.subtitles,
  });

  @override
  String toString() {
    return 'VideoMetadata(\n'
        '  title: $title,\n'
        '  author: $author,\n'
        '  duration: $duration,\n'
        '  videoStreams: ${videoStreams.length},\n'
        '  audioStreams: ${audioStreams.length},\n'
        '  subtitles: ${subtitles.length}\n'
        ')';
  }
}

class AppVideoStreamInfo {
  final String tag;
  final String codec;
  final String quality;
  final double sizeInMb;

  AppVideoStreamInfo({
    required this.tag,
    required this.codec,
    required this.quality,
    required this.sizeInMb,
  });
}

class AppAudioStreamInfo {
  final String tag;
  final String codec;
  final double sizeInMb;

  AppAudioStreamInfo({
    required this.tag,
    required this.codec,
    required this.sizeInMb,
  });
}
