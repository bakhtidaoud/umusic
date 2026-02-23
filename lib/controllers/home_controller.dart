import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart' as dio;
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
  var currentQuery = 'trending'.obs;
  var currentCategory = 'All'.obs;

  var suggestions = <String>[].obs;
  var showSuggestions = false.obs;
  var searchText = ''.obs;

  var userName = 'Music Lover'.obs;
  var userImageUrl = ''.obs;
  var dynamicCategories = <String>[].obs;

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
      // Ensure GeoService is ready
      final geoService = Get.find<GeoService>();
      if (geoService.countryCode.value == 'US') {
        await geoService.loadCachedCountry();
      }

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
      final country = geoService.countryCode.value;

      // Logic for authentic YouTube Index or specialized search
      if (finalQuery == 'trending' && currentCategory.value == 'All') {
        if (isLoggedIn.value && cookies != null) {
          try {
            results = await _fetchYouTubeHomeFeed(cookies);
          } catch (e) {
            debugPrint('Error fetching home feed: $e');
            final searchResult = await _yt.search.getVideos(
              'trending $country',
            );
            results = searchResult.toList();
          }
        } else {
          final searchResult = await _yt.search.getVideos('trending $country');
          results = searchResult.toList();
        }
      } else {
        String searchQuery = finalQuery;
        if (currentCategory.value != 'All') {
          searchQuery = '${currentCategory.value} $finalQuery';
        }
        final searchResult = await _yt.search.getVideos(searchQuery);
        results = searchResult.toList();
      }

      final categorization = await compute(_categorizeVideos, results);
      var filteredRegular = categorization['regular']!;
      var filteredShorts = categorization['shorts']!;

      if (filteredShorts.length < 5 && (query == null || query == 'trending')) {
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

      if (finalQuery == 'trending' && currentCategory.value == 'All') {
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
    fetchVideos(query: query.isEmpty ? 'trending' : query);
  }

  void setCategory(String category) {
    if (currentCategory.value == category) return;
    fetchVideos(category: category);
  }

  Future<List<Video>> _fetchYouTubeHomeFeed(String cookies) async {
    try {
      final response = await _dio.get(
        'https://www.youtube.com/',
        options: dio.Options(
          headers: {
            'Cookie': cookies,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          },
        ),
      );

      final html = response.data.toString();
      // More resilient regex for ytInitialData
      final regex = RegExp(r'(?:var\s+)?ytInitialData\s*=\s*(\{.*?\});');
      final match = regex.firstMatch(html);

      if (match != null) {
        final jsonStr = match.group(1);
        final dynamic data = jsonDecode(jsonStr!);

        // Try to extract user info
        try {
          var topbar = data['topbar']?['desktopTopbarRenderer'];
          var avatar = topbar?['topbarButtons']?[3]?['topbarMenuButtonRenderer']?['avatar']?['thumbnails']?[0]?['url'];
          
          // Alternative path for avatar
          avatar ??= data['responseContext']?['mainAppWebResponseContext']?['loggedOutAvatar']?['thumbnails']?[0]?['url'];
          
          if (avatar != null) userImageUrl.value = avatar;

          // Attempt to get name from accessibility data or other fields
          // Note: Full name is often harder to get silently, but we can try common paths
          var accountButton = topbar?['topbarButtons']?.firstWhere((b) => b['topbarMenuButtonRenderer'] != null, orElse: () => null);
          var nameText = accountButton?['topbarMenuButtonRenderer']?['accessibility']?['accessibilityData']?['label'];
          if (nameText != null && nameText.toString().contains(',')) {
             // Often "Account profile: Full Name"
             userName.value = nameText.split(':').last.trim();
          }
        } catch (e) {
          debugPrint('User info extraction error: $e');
        }

        // Try to extract categories
        try {
          var header = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['richGridRenderer']?['header']?['feedFilterChipBarRenderer'];
          if (header != null) {
            var chips = header['contents'] as List?;
            if (chips != null) {
              final newCats = <String>['All'];
              for (var chip in chips) {
                var text = chip['chipCloudChipRenderer']?['text']?['simpleText'] ?? 
                           chip['chipCloudChipRenderer']?['text']?['runs']?[0]?['text'];
                if (text != null && text != 'All') {
                  newCats.add(text);
                }
              }
              if (newCats.length > 1) {
                dynamicCategories.assignAll(newCats);
              }
            }
          }
        } catch (e) {
          debugPrint('Categories extraction error: $e');
        }

        final List<String> videoIds = [];

        try {
          void traverse(dynamic node) {
            if (node is Map) {
              if (node.containsKey('videoId') && node['videoId'] is String) {
                if (!videoIds.contains(node['videoId'])) {
                  videoIds.add(node['videoId']);
                }
              }
              node.forEach((_, value) => traverse(value));
            } else if (node is List) {
              for (var e in node) {
                traverse(e);
              }
            }
          }

          traverse(data);
        } catch (e) {
          debugPrint('Parsing error: $e');
        }

        if (videoIds.isNotEmpty) {
          final List<Video> finalVideos = [];
          final idsToFetch = videoIds.take(15).toList();

          // Fetch in parallel
          final futures = idsToFetch.map((id) => _yt.videos.get(id));
          final results = await Future.wait(futures);
          finalVideos.addAll(results);

          return finalVideos;
        }
      }
    } catch (e) {
      debugPrint('Scraping error: $e');
    }

    final searchResult = await _yt.search.getVideos('recommended videos');
    return searchResult.toList();
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
