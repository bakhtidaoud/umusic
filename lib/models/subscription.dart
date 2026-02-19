import 'dart:convert';

class Subscription {
  final String url;
  final String title;
  final DateTime lastChecked;
  final List<String> knownVideoIds;
  final bool autoDownload;

  Subscription({
    required this.url,
    required this.title,
    required this.lastChecked,
    required this.knownVideoIds,
    this.autoDownload = true,
  });

  Subscription copyWith({
    String? title,
    DateTime? lastChecked,
    List<String>? knownVideoIds,
    bool? autoDownload,
  }) {
    return Subscription(
      url: url,
      title: title ?? this.title,
      lastChecked: lastChecked ?? this.lastChecked,
      knownVideoIds: knownVideoIds ?? this.knownVideoIds,
      autoDownload: autoDownload ?? this.autoDownload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'lastChecked': lastChecked.toIso8601String(),
      'knownVideoIds': knownVideoIds,
      'autoDownload': autoDownload,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      lastChecked: DateTime.parse(map['lastChecked']),
      knownVideoIds: List<String>.from(map['knownVideoIds'] ?? []),
      autoDownload: map['autoDownload'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());
  factory Subscription.fromJson(String source) =>
      Subscription.fromMap(json.decode(source));
}
