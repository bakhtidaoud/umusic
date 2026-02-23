import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GeoService extends GetxService {
  final Dio _dio = Dio();
  final String _cacheKey = 'user_country_code';

  final countryCode = 'US'.obs; // Default to US

  @override
  void onInit() {
    super.onInit();
    init();
  }

  Future<void> init() async {
    await loadCachedCountry();
  }

  Future<void> loadCachedCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        countryCode.value = cached;
        debugPrint('GeoService: Loaded cached country code: $cached');
      } else {
        await fetchCountryCode();
      }
    } catch (e) {
      debugPrint('GeoService: Error loading cached country: $e');
    }
  }

  Future<String> fetchCountryCode() async {
    try {
      debugPrint('GeoService: Fetching country code from ipinfo.io...');
      final response = await _dio.get(
        'https://ipinfo.io/json',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final code = response.data['country'] as String?;
        if (code != null && code.length == 2) {
          countryCode.value = code;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, code);

          debugPrint(
            'GeoService: Successfully fetched and cached country: $code',
          );
          return code;
        }
      }
    } catch (e) {
      debugPrint('GeoService: Error fetching country code: $e');
    }
    return countryCode.value;
  }

  /// Forces a refresh of the country code
  Future<void> refreshLocation() async {
    await fetchCountryCode();
  }
}
