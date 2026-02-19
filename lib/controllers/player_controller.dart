import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:video_player/video_player.dart';
import 'package:pod_player/pod_player.dart';

class PlayerController extends GetxController {
  final YoutubeExplode _yt = YoutubeExplode();
  late PodPlayerController podController;
  var isLoading = true.obs;
  var videoTitle = ''.obs;
  var channelName = ''.obs;

  Future<void> initPlayer(String videoUrl) async {
    isLoading.value = true;
    try {
      final video = await _yt.videos.get(videoUrl);
      videoTitle.value = video.title;
      channelName.value = video.author;

      podController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.youtube(videoUrl),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: [720, 360],
        ),
      )..initialise();

      isLoading.value = false;
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize player: $e');
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    podController.dispose();
    _yt.close();
    super.onClose();
  }
}
