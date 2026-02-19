import 'dart:convert';

class AppConfig {
  final String? downloadFolder;
  final String preferredQuality;
  final String preferredFormat; // 'audio' or 'video'
  final int maxConcurrentDownloads;
  final String? proxySettings;
  final String themeMode; // 'light', 'dark', 'system'
  final String preferredVideoCodec; // 'h264', 'vp9', 'av1'
  final String preferredAudioQuality; // 'best', '128k', '320k'
  final int networkTimeout; // in seconds
  final String? cookiesFile;
  final String? archiveFile;

  final bool smartModeEnabled;
  final String? lastFormatType;
  final String? lastQualityId;

  AppConfig({
    this.downloadFolder,
    this.preferredQuality = 'Highest',
    this.preferredFormat = 'video',
    this.maxConcurrentDownloads = 3,
    this.proxySettings,
    this.themeMode = 'system',
    this.preferredVideoCodec = 'h264',
    this.preferredAudioQuality = 'best',
    this.networkTimeout = 30,
    this.cookiesFile,
    this.archiveFile,
    this.smartModeEnabled = false,
    this.lastFormatType,
    this.lastQualityId,
  });

  AppConfig copyWith({
    String? downloadFolder,
    String? preferredQuality,
    String? preferredFormat,
    int? maxConcurrentDownloads,
    String? proxySettings,
    String? themeMode,
    String? preferredVideoCodec,
    String? preferredAudioQuality,
    int? networkTimeout,
    String? cookiesFile,
    String? archiveFile,
    bool? smartModeEnabled,
    String? lastFormatType,
    String? lastQualityId,
  }) {
    return AppConfig(
      downloadFolder: downloadFolder ?? this.downloadFolder,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      preferredFormat: preferredFormat ?? this.preferredFormat,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      proxySettings: proxySettings ?? this.proxySettings,
      themeMode: themeMode ?? this.themeMode,
      preferredVideoCodec: preferredVideoCodec ?? this.preferredVideoCodec,
      preferredAudioQuality:
          preferredAudioQuality ?? this.preferredAudioQuality,
      networkTimeout: networkTimeout ?? this.networkTimeout,
      cookiesFile: cookiesFile ?? this.cookiesFile,
      archiveFile: archiveFile ?? this.archiveFile,
      smartModeEnabled: smartModeEnabled ?? this.smartModeEnabled,
      lastFormatType: lastFormatType ?? this.lastFormatType,
      lastQualityId: lastQualityId ?? this.lastQualityId,
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
      'preferredVideoCodec': preferredVideoCodec,
      'preferredAudioQuality': preferredAudioQuality,
      'networkTimeout': networkTimeout,
      'cookiesFile': cookiesFile,
      'archiveFile': archiveFile,
      'smartModeEnabled': smartModeEnabled,
      'lastFormatType': lastFormatType,
      'lastQualityId': lastQualityId,
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
      preferredVideoCodec: map['preferredVideoCodec'] ?? 'h264',
      preferredAudioQuality: map['preferredAudioQuality'] ?? 'best',
      networkTimeout: map['networkTimeout'] ?? 30,
      cookiesFile: map['cookiesFile'] as String?,
      archiveFile: map['archiveFile'] as String?,
      smartModeEnabled: map['smartModeEnabled'] ?? false,
      lastFormatType: map['lastFormatType'] as String?,
      lastQualityId: map['lastQualityId'] as String?,
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
