import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

class ConfigController extends GetxController {
  static const String _configKey = 'app_config';
  final SharedPreferences _prefs;
  final Rx<AppConfig> _config = AppConfig().obs;

  ConfigController(this._prefs) {
    _loadConfig();
  }

  AppConfig get config => _config.value;

  void _loadConfig() {
    final String? configJson = _prefs.getString(_configKey);
    if (configJson != null) {
      try {
        _config.value = AppConfig.fromJson(configJson);
      } catch (e) {
        debugPrint('Error loading config: $e');
        _config.value = AppConfig();
      }
    } else {
      _config.value = AppConfig();
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config.value = newConfig;
    await _prefs.setString(_configKey, _config.value.toJson());
  }

  Future<void> setDownloadFolder(String path) async {
    await updateConfig(_config.value.copyWith(downloadFolder: path));
  }

  Future<void> setPreferredQuality(String quality) async {
    await updateConfig(_config.value.copyWith(preferredQuality: quality));
  }

  Future<void> setPreferredFormat(String format) async {
    await updateConfig(_config.value.copyWith(preferredFormat: format));
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    await updateConfig(_config.value.copyWith(maxConcurrentDownloads: count));
  }

  Future<void> setProxySettings(String? proxy) async {
    await updateConfig(_config.value.copyWith(proxySettings: proxy));
  }

  Future<void> setThemeMode(String mode) async {
    await updateConfig(_config.value.copyWith(themeMode: mode));
    Get.changeThemeMode(_getThemeMode(mode));
  }

  Future<void> setSmartMode(bool enabled) async {
    await updateConfig(_config.value.copyWith(smartModeEnabled: enabled));
  }

  Future<void> setLastSettings(String formatType, String qualityId) async {
    await updateConfig(
      _config.value.copyWith(
        lastFormatType: formatType,
        lastQualityId: qualityId,
      ),
    );
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
