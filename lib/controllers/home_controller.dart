import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cookie_controller.dart';
import '../services/geo_service.dart';
import '../services/extraction_service.dart';
import '../services/cache_service.dart';

class HomeController extends GetxController {
  late YoutubeExplode _yt;
  final dio.Dio _dio = dio.Dio();

  var videos = <Video>[].obs;
  var shorts = <Video>[].obs;
  var isLoading = true.obs;
  var isLoggedIn = false.obs;
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
    checkLoginStatus();
    fetchVideos();

    searchController.addListener(_onSearchChanged);
  }

  Future<void> checkLoginStatus() async {
    final cookieController = Get.find<CookieController>();
    final cookies = await cookieController.getCookieString(
      Uri.parse('https://www.youtube.com'),
    );
    isLoggedIn.value = cookies != null && cookies.isNotEmpty;
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
      await checkLoginStatus();

      final cookieController = Get.find<CookieController>();
      final cookies = await cookieController.getCookieString(
        Uri.parse('https://www.youtube.com'),
      );

      if (cookies != null) {
        if (Get.isRegistered<ExtractionService>()) {
          Get.find<ExtractionService>().setCookies(cookies);
        }
      }

      if (query != null) currentQuery.value = query;
      if (category != null) currentCategory.value = category;

      List<Video> results = [];
      String finalQuery = currentQuery.value;
      final geoService = Get.find<GeoService>();
      final country = geoService.countryCode.value;

      // Logic for personalized or trending feed
      if (finalQuery == 'trending music' && currentCategory.value == 'All') {
        if (isLoggedIn.value) {
          // If logged in, we search for generic "music" which often returns personalized results with cookies
          // or we could try to get their subscription feed if the library supported it.
          // For now, we search for broad terms that benefit from personalization.
          final searchResult = await _yt.search.getVideos(
            'music recommendations',
            filter: TypeFilters.video,
          );
          results = searchResult.toList();
        } else {
          // If NOT logged in, get country-specific trending
          // We'll use search for trending topics which is more reliable across library versions
          final searchResult = await _yt.search.getVideos(
            'trending music $country',
          );
          results = searchResult.toList();
        }
      } else {
        // Normal search or category filter
        String searchQuery = finalQuery;
        if (currentCategory.value != 'All') {
          searchQuery = '${currentCategory.value} $finalQuery';
        }
        final searchResult = await _yt.search.getVideos(searchQuery);
        results = searchResult.toList();
      }

      // Filter Shorts and Regular videos in an isolate for performance
      final categorization = await compute(_categorizeVideos, results);
      var filteredRegular = categorization['regular']!;
      var filteredShorts = categorization['shorts']!;

      // If we didn't get enough shorts from the results, specifically fetch some
      if (filteredShorts.length < 5 &&
          (query == null || query == 'trending music')) {
        final shortResults = await _yt.search.getVideos(
          isLoggedIn.value
              ? 'shorts recommendations'
              : 'trending shorts $country',
        );
        final moreCategorization = await compute(
          _categorizeVideos,
          shortResults.toList(),
        );
        final moreShorts = moreCategorization['shorts']!;

        for (var v in moreShorts) {
          if (!filteredShorts.any((existing) => existing.id == v.id)) {
            filteredShorts.add(v);
          }
        }
      }

      videos.assignAll(filteredRegular.take(30));
      shorts.assignAll(filteredShorts.take(15));

      // Persistently cache trending results
      if (finalQuery == 'trending music' && currentCategory.value == 'All') {
        final cacheService = Get.find<CacheService>();
        await cacheService.cacheSearchResults(
          'trending_$country',
          videos.map((v) => v.id.value).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error fetching videos: $e');
      Get.snackbar(
        'Error',
        'Failed to load videos. Please try again.',
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

Map<String, List<Video>> _categorizeVideos(List<Video> videos) {
  final List<Video> shorts = [];
  final List<Video> regular = [];

  for (var v in videos) {
    if (v.duration != null && v.duration!.inSeconds < 70) {
      shorts.add(v);
    } else {
      regular.add(v);
    }
  }

  return {'shorts': shorts, 'regular': regular};
}
