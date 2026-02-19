import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class ConfigService extends ChangeNotifier {
  static const String _configKey = 'app_config';
  final SharedPreferences _prefs;
  late AppConfig _config;

  ConfigService(this._prefs) {
    _loadConfig();
  }

  AppConfig get config => _config;

  void _loadConfig() {
    final String? configJson = _prefs.getString(_configKey);
    if (configJson != null) {
      try {
        _config = AppConfig.fromJson(configJson);
      } catch (e) {
        debugPrint('Error loading config: $e');
        _config = AppConfig();
      }
    } else {
      _config = AppConfig();
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    await _prefs.setString(_configKey, _config.toJson());
    notifyListeners();
  }

  // Individual update methods for convenience
  Future<void> setDownloadFolder(String path) async {
    await updateConfig(_config.copyWith(downloadFolder: path));
  }

  Future<void> setPreferredQuality(String quality) async {
    await updateConfig(_config.copyWith(preferredQuality: quality));
  }

  Future<void> setPreferredFormat(String format) async {
    await updateConfig(_config.copyWith(preferredFormat: format));
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    await updateConfig(_config.copyWith(maxConcurrentDownloads: count));
  }

  Future<void> setProxySettings(String? proxy) async {
    await updateConfig(_config.copyWith(proxySettings: proxy));
  }

  Future<void> setThemeMode(String mode) async {
    await updateConfig(_config.copyWith(themeMode: mode));
  }
}
