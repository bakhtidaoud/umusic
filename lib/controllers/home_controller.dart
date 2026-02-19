import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/material.dart';

class HomeController extends GetxController {
  final YoutubeExplode _yt = YoutubeExplode();
  var videos = <Video>[].obs;
  var isLoading = true.obs;
  var currentQuery = 'trending music'.obs;
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchVideos();
  }

  Future<void> fetchVideos({String? query}) async {
    isLoading.value = true;
    try {
      if (query != null) currentQuery.value = query;
      final result = await _yt.search.getVideos(currentQuery.value);
      videos.assignAll(result.take(30));
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load videos: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      fetchVideos(query: 'trending music');
    } else {
      fetchVideos(query: query);
    }
  }

  @override
  void onClose() {
    _yt.close();
    searchController.dispose();
    super.onClose();
  }
}
