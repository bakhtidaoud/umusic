import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import 'extraction_service.dart';
import 'download_service.dart';

class SubscriptionService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ExtractionService _extractionService;
  final DownloadService _downloadService;

  List<Subscription> _subscriptions = [];
  Timer? _checkTimer;
  bool _isChecking = false;
  int _newDownloadsCount = 0;

  SubscriptionService(
    this._prefs,
    this._extractionService,
    this._downloadService,
  ) {
    _loadSubscriptions();
    // Check every hour
    _checkTimer = Timer.periodic(
      const Duration(hours: 1),
      (timer) => checkNewContent(),
    );
  }

  List<Subscription> get subscriptions => _subscriptions;
  bool get isChecking => _isChecking;
  int get newDownloadsCount => _newDownloadsCount;

  void _loadSubscriptions() {
    final List<String>? subsJson = _prefs.getStringList('subscriptions');
    if (subsJson != null) {
      _subscriptions = subsJson.map((s) => Subscription.fromJson(s)).toList();
    }
  }

  Future<void> _saveSubscriptions() async {
    final List<String> subsJson = _subscriptions
        .map((s) => s.toJson())
        .toList();
    await _prefs.setStringList('subscriptions', subsJson);
    notifyListeners();
  }

  Future<void> addSubscription(String url) async {
    final metadata = await _extractionService.getMetadata(url);
    if (metadata == null) return;

    final sub = Subscription(
      url: url,
      title: metadata.title,
      lastChecked: DateTime.now(),
      knownVideoIds: metadata.entries.map((e) => e.url).toList(),
    );

    _subscriptions.add(sub);
    await _saveSubscriptions();
  }

  Future<void> removeSubscription(String url) async {
    _subscriptions.removeWhere((s) => s.url == url);
    await _saveSubscriptions();
  }

  Future<void> checkNewContent() async {
    if (_isChecking) return;
    _isChecking = true;
    _newDownloadsCount = 0;
    notifyListeners();

    for (int i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      final metadata = await _extractionService.getMetadata(sub.url);

      if (metadata != null) {
        final List<String> currentIds = metadata.entries
            .map((e) => e.url)
            .toList();
        final newEntries = metadata.entries
            .where((e) => !sub.knownVideoIds.contains(e.url))
            .toList();

        if (newEntries.isNotEmpty) {
          if (sub.autoDownload) {
            _downloadService.downloadBatch(newEntries);
            _newDownloadsCount += newEntries.length;
          }

          _subscriptions[i] = sub.copyWith(
            lastChecked: DateTime.now(),
            knownVideoIds: currentIds,
          );
        } else {
          _subscriptions[i] = sub.copyWith(lastChecked: DateTime.now());
        }
      }
    }

    _isChecking = false;
    await _saveSubscriptions();
    notifyListeners();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
