import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:pod_player/pod_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import '../utils/design_system.dart';
import 'library_controller.dart';

class PlayerController extends GetxController {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  PodPlayerController? podController;

  var isLoading = false.obs;
  var isPlaying = false.obs;
  var videoTitle = ''.obs;
  var channelName = ''.obs;
  var videoDescription = ''.obs;
  var thumbnailUrl = ''.obs;
  var currentVideoUrl = ''.obs;

  var isBackgroundMode = false.obs;
  var showMiniPlayer = false.obs;
  var isLiked = false.obs;
  var isSaved = false.obs;
  var isLocalFile = false.obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to audio player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (isBackgroundMode.value || isLocalFile.value) {
        isPlaying.value = state.playing;
      }
    });
  }

  Future<void> initPlayer(String videoUrl) async {
    // Check if it's a local file
    if (videoUrl.startsWith('/') ||
        videoUrl.contains(':\\') ||
        !videoUrl.startsWith('http')) {
      final file = File(videoUrl);
      if (await file.exists()) {
        final ext = videoUrl.split('.').last.toLowerCase();
        return playLocalFile(
          LocalFile(
            path: videoUrl,
            name: videoUrl.split(Platform.pathSeparator).last,
            extension: '.$ext',
            modified: DateTime.now(),
            size: await file.length(),
          ),
        );
      }
    }

    isLocalFile.value = false;
    // If playing the same video and miniplayer is shown, don't re-init
    if (currentVideoUrl.value == videoUrl && podController != null) {
      Future.microtask(() => showMiniPlayer.value = false);
      return;
    }

    Future.microtask(() {
      isLoading.value = true;
      showMiniPlayer.value = false;
      currentVideoUrl.value = videoUrl;
      errorMessage.value = '';
    });

    try {
      final video = await _yt.videos.get(videoUrl);
      videoTitle.value = video.title;
      channelName.value = video.author;
      videoDescription.value = video.description;
      thumbnailUrl.value = video.thumbnails.highResUrl;

      if (podController != null) {
        podController!.dispose();
      }

      final videoId = video.id.value;
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final muxedStreams = manifest.muxed.toList();

      final List<VideoQalityUrls> qualityUrls = [];
      for (var s in muxedStreams) {
        final q = s.videoQuality.toString().replaceAll(RegExp(r'[^0-9]'), '');
        qualityUrls.add(
          VideoQalityUrls(
            quality: int.tryParse(q) ?? 360,
            url: s.url.toString(),
          ),
        );
      }

      try {
        podController = PodPlayerController(
          playVideoFrom: PlayVideoFrom.youtube(videoUrl),
          podPlayerConfig: PodPlayerConfig(
            autoPlay: true,
            isLooping: false,
            forcedVideoFocus: true,
          ),
        );
        await podController!.initialise();
      } catch (podError) {
        podController = PodPlayerController(
          playVideoFrom: PlayVideoFrom.networkQualityUrls(
            videoUrls: qualityUrls,
          ),
          podPlayerConfig: PodPlayerConfig(autoPlay: true, isLooping: false),
        );
        await podController!.initialise();
      }

      podController!.play();

      podController!.addListener(() {
        if (!isBackgroundMode.value && !isLocalFile.value) {
          final vControl = (podController as dynamic).videoPlayerController;
          if (vControl != null) {
            isPlaying.value = vControl.value.isPlaying;
          }
        }
      });

      isLoading.value = false;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('Error', 'Failed to initialize player: $e');
      isLoading.value = false;
    }
  }

  Future<void> playLocalFile(LocalFile file) async {
    final isVideo = ['.mp4', '.mkv', '.webm'].contains(file.extension);
    isLocalFile.value = true;
    currentVideoUrl.value = file.path;
    videoTitle.value = file.name;
    channelName.value = 'Local Storage';
    thumbnailUrl.value = file.thumbnailPath ?? '';
    videoDescription.value = 'Playing from local library: ${file.path}';

    if (podController != null) {
      podController!.dispose();
      podController = null;
    }
    await _audioPlayer.stop();

    if (isVideo) {
      isBackgroundMode.value = false;
      podController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.file(File(file.path)),
        podPlayerConfig: PodPlayerConfig(autoPlay: true, isLooping: false),
      );
      await podController!.initialise();
      podController!.play();

      podController!.addListener(() {
        final vControl = (podController as dynamic).videoPlayerController;
        if (vControl != null) {
          isPlaying.value = vControl.value.isPlaying;
        }
      });
    } else {
      isBackgroundMode.value = true;
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.file(file.path),
          tag: MediaItem(
            id: file.path,
            title: file.name,
            album: 'Local Library',
            artUri: file.thumbnailPath != null
                ? Uri.file(file.thumbnailPath!)
                : null,
          ),
        ),
      );
      _audioPlayer.play();
    }

    showMiniPlayer.value = true;
  }

  void toggleBackgroundMode(bool value) async {
    if (isLocalFile.value) return;
    isBackgroundMode.value = value;
    if (value) {
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
    if (isBackgroundMode.value ||
        (isLocalFile.value && podController == null)) {
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

  void toggleLike() {
    isLiked.value = !isLiked.value;
    Get.snackbar(
      isLiked.value ? 'Liked' : 'Unliked',
      isLiked.value ? 'Added to liked videos' : 'Removed from liked videos',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isLiked.value
          ? UDesign.primary.withOpacity(0.7)
          : Colors.black54,
      colorText: Colors.white,
    );
  }

  void toggleSave() {
    isSaved.value = !isSaved.value;
    Get.snackbar(
      isSaved.value ? 'Saved' : 'Unsaved',
      isSaved.value ? 'Added to your library' : 'Removed from library',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isSaved.value
          ? UDesign.primary.withOpacity(0.7)
          : Colors.black54,
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    podController?.dispose();
    _audioPlayer.dispose();
    _yt.close();
    super.onClose();
  }
}
