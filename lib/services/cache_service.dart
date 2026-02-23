import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'extraction_service.dart';

class CacheService extends GetxService {
  late SharedPreferences _prefs;
  static const String _metadataPrefix = 'meta_';
  static const String _searchPrefix = 'search_';

  Future<CacheService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // --- Metadata Caching ---

  Future<void> cacheMetadata(String url, UniversalMetadata metadata) async {
    try {
      // For caching we don't need the formats if it's too much, but let's try to cache everything
      // We need a way to serialize UniversalMetadata
      // Since it's a complex object, we'll skip serializing the whole thing for now
      // and only cache basic info or implement a proper toMap()
    } catch (e) {
      print('Error caching metadata: $e');
    }
  }

  // --- Search Results Caching ---

  Future<void> cacheSearchResults(String query, List<dynamic> results) async {
    final key = '$_searchPrefix${query.hashCode}';
    // We only cache the IDs or basic info
    final data = results.map((e) => e.toString()).toList();
    await _prefs.setStringList(key, data);
    await _prefs.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
  }

  List<String>? getCachedSearchResults(String query) {
    final key = '$_searchPrefix${query.hashCode}';
    final timestamp = _prefs.getInt('${key}_time');
    if (timestamp == null) return null;

    // Cache valid for 1 hour
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > 3600000) {
      _prefs.remove(key);
      _prefs.remove('${key}_time');
      return null;
    }

    return _prefs.getStringList(key);
  }

  // --- Image Caching is handled by CachedNetworkImage ---

  Future<double> getCacheSize() async {
    // Basic estimation: Prefs + App Support Dir (where cookies/bins are) is not really cache
    // But we can measure the number of keys.
    final keys = _prefs.getKeys().where(
      (k) => k.startsWith(_metadataPrefix) || k.startsWith(_searchPrefix),
    );
    return keys.length * 0.05; // Dummy calculation: ~50KB per entry in MB
  }

  Future<void> clearCache() async {
    final keys = _prefs.getKeys().where(
      (k) => k.startsWith(_metadataPrefix) || k.startsWith(_searchPrefix),
    );
    for (final key in keys) {
      await _prefs.remove(key);
    }
    // Also clear GetX memory cache if any
    if (Get.isRegistered<ExtractionService>()) {
      // ExtractionService._cache is private, but we can restart it or similar if needed.
    }
  }
}
