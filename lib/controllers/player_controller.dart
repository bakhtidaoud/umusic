import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:pod_player/pod_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';

class PlayerController extends GetxController {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  PodPlayerController? podController;

  var isLoading = false.obs;
  var isPlaying = false.obs;
  var videoTitle = ''.obs;
  var channelName = ''.obs;
  var thumbnailUrl = ''.obs;
  var currentVideoUrl = ''.obs;

  var isBackgroundMode = false.obs;
  var showMiniPlayer = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to audio player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (isBackgroundMode.value) {
        isPlaying.value = state.playing;
      }
    });
  }

  Future<void> initPlayer(String videoUrl) async {
    // If playing the same video and miniplayer is shown, don't re-init
    if (currentVideoUrl.value == videoUrl && podController != null) {
      showMiniPlayer.value = false;
      return;
    }

    isLoading.value = true;
    showMiniPlayer.value = false;
    currentVideoUrl.value = videoUrl;

    try {
      final video = await _yt.videos.get(videoUrl);
      videoTitle.value = video.title;
      channelName.value = video.author;
      thumbnailUrl.value = video.thumbnails.highResUrl;

      // Dispose previous controller if exists
      if (podController != null) {
        podController!.dispose();
      }

      podController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.youtube(videoUrl),
        podPlayerConfig: PodPlayerConfig(autoPlay: true, isLooping: false),
      );

      await podController!.initialise();

      // Listen to play/pause state
      podController!.addListener(() {
        if (!isBackgroundMode.value) {
          // Using dynamic to bypass version-specific lint issues if property exists
          isPlaying.value =
              (podController as dynamic)
                  .videoPlayerController
                  ?.value
                  .isPlaying ??
              false;
        }
      });

      isLoading.value = false;
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize player: $e');
      isLoading.value = false;
    }
  }

  void toggleBackgroundMode(bool value) async {
    isBackgroundMode.value = value;
    if (value) {
      // Background logic using just_audio for better reliability
      try {
        final videoId = VideoId(currentVideoUrl.value);
        final manifest = await _yt.videos.streamsClient.getManifest(videoId);
        final audioStream = manifest.audioOnly.withHighestBitrate();

        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioStream.url.toString()),
            tag: MediaItem(
              id: currentVideoUrl.value,
              album: channelName.value,
              title: videoTitle.value,
              artUri: Uri.parse(thumbnailUrl.value),
            ),
          ),
        );

        if ((podController as dynamic).videoPlayerController?.value.isPlaying ??
            false) {
          podController!.pause();
          _audioPlayer.play();
        }
      } catch (e) {
        Get.snackbar(
          'Background Error',
          'Could not switch to background audio',
        );
        isBackgroundMode.value = false;
      }
    } else {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        if (podController != null) {
          // Sync position back to video if possible
          final vControl = (podController as dynamic).videoPlayerController;
          if (vControl != null) {
            await vControl.seekTo(_audioPlayer.position);
          }
          podController!.play();
        }
      }
    }
  }

  void togglePlayPause() {
    if (isBackgroundMode.value) {
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
      return;
    }

    if (podController == null) return;
    final vControl = (podController as dynamic).videoPlayerController;
    if (vControl != null && (vControl.value.isPlaying as bool)) {
      podController!.pause();
    } else {
      podController!.play();
    }
  }

  void minimize() {
    showMiniPlayer.value = true;
    Get.back();
  }

  void stopAndDismiss() {
    showMiniPlayer.value = false;
    podController?.pause();
    _audioPlayer.stop();
    currentVideoUrl.value = '';
  }

  @override
  void onClose() {
    podController?.dispose();
    _audioPlayer.dispose();
    _yt.close();
    super.onClose();
  }
}
