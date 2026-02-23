import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'dart:async';
import 'cookie_controller.dart';
import '../services/extraction_service.dart';

class HomeController extends GetxController {
  late YoutubeExplode _yt;
  final dio.Dio _dio = dio.Dio();

  var videos = <Video>[].obs;
  var shorts = <Video>[].obs;
  var isLoading = true.obs;
  var currentQuery = 'trending music'.obs;
  var currentCategory = 'All'.obs;

  var suggestions = <String>[].obs;
  var showSuggestions = false.obs;
  var searchText = ''.obs;

  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  final List<String> categories = [
    'All',
    'Music',
    'Gaming',
    'News',
    'Movies',
    'Live',
    'Comedy',
    'Technology',
  ];

  @override
  void onInit() {
    super.onInit();
    _yt = YoutubeExplode();
    fetchVideos();

    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    searchText.value = searchController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchSuggestions(searchController.text);
    });
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.isEmpty) {
      suggestions.clear();
      showSuggestions.value = false;
      return;
    }

    try {
      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=$query',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data[1];
        suggestions.assignAll(data.map((e) => e.toString()).toList());
        showSuggestions.value = suggestions.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  Future<void> fetchVideos({String? query, String? category}) async {
    isLoading.value = true;
    showSuggestions.value = false;

    try {
      // Get cookies and update YouTube client for personalized results
      final cookieController = Get.find<CookieController>();
      final cookies = await cookieController.getCookieString(
        Uri.parse('https://www.youtube.com'),
      );

      if (cookies != null) {
        _yt.close();
        _yt = YoutubeExplode(); // Re-init with cookies if needed by lib,
        // though youtube_explode_dart doesn't have a direct cookie constructor,
        // we can set headers if we were using a custom client.
        // For now, we'll ensure extraction service is also updated.
        if (Get.isRegistered<ExtractionService>()) {
          Get.find<ExtractionService>().setCookies(cookies);
        }
      }

      if (query != null) currentQuery.value = query;
      if (category != null) currentCategory.value = category;

      String finalQuery = currentQuery.value;
      if (currentCategory.value != 'All') {
        finalQuery = '${currentCategory.value} $finalQuery';
      }

      final result = await _yt.search.getVideos(finalQuery);

      // Filter Shorts (roughly videos < 70 seconds or with "shorts" in metadata)
      final allVids = result.toList();
      final List<Video> filteredShorts = [];
      final List<Video> filteredRegular = [];

      for (var v in allVids) {
        if (v.duration != null && v.duration!.inSeconds < 70) {
          filteredShorts.add(v);
        } else {
          filteredRegular.add(v);
        }
      }

      videos.assignAll(filteredRegular.take(20));
      shorts.assignAll(filteredShorts.take(15));
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
    searchController.text = query;
    fetchVideos(query: query.isEmpty ? 'trending music' : query);
  }

  void setCategory(String category) {
    if (currentCategory.value == category) return;
    fetchVideos(category: category);
  }

  @override
  void onClose() {
    _yt.close();
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
