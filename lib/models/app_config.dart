import 'dart:convert';

class AppConfig {
  final String? downloadFolder;
  final String preferredQuality;
  final String preferredFormat; // 'audio' or 'video'
  final int maxConcurrentDownloads;
  final String? proxySettings;
  final String themeMode; // 'light', 'dark', 'system'

  AppConfig({
    this.downloadFolder,
    this.preferredQuality = 'Highest',
    this.preferredFormat = 'video',
    this.maxConcurrentDownloads = 3,
    this.proxySettings,
    this.themeMode = 'system',
  });

  AppConfig copyWith({
    String? downloadFolder,
    String? preferredQuality,
    String? preferredFormat,
    int? maxConcurrentDownloads,
    String? proxySettings,
    String? themeMode,
  }) {
    return AppConfig(
      downloadFolder: downloadFolder ?? this.downloadFolder,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      preferredFormat: preferredFormat ?? this.preferredFormat,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      proxySettings: proxySettings ?? this.proxySettings,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'downloadFolder': downloadFolder,
      'preferredQuality': preferredQuality,
      'preferredFormat': preferredFormat,
      'maxConcurrentDownloads': maxConcurrentDownloads,
      'proxySettings': proxySettings,
      'themeMode': themeMode,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      downloadFolder: map['downloadFolder'] as String?,
      preferredQuality: map['preferredQuality'] ?? 'Highest',
      preferredFormat: map['preferredFormat'] ?? 'video',
      maxConcurrentDownloads: map['maxConcurrentDownloads'] ?? 3,
      proxySettings: map['proxySettings'] as String?,
      themeMode: map['themeMode'] ?? 'system',
    );
  }

  String toJson() => json.encode(toMap());

  factory AppConfig.fromJson(String source) =>
      AppConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'AppConfig(downloadFolder: $downloadFolder, preferredQuality: $preferredQuality, preferredFormat: $preferredFormat, maxConcurrentDownloads: $maxConcurrentDownloads, proxySettings: $proxySettings, themeMode: $themeMode)';
  }
}
