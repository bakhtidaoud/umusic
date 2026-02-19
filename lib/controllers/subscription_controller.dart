import 'dart:async';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../services/extraction_service.dart';
import 'download_controller.dart';

class SubscriptionController extends GetxController {
  final SharedPreferences _prefs;

  final RxList<Subscription> subscriptions = <Subscription>[].obs;
  Timer? _checkTimer;
  var isChecking = false.obs;
  var newDownloadsCount = 0.obs;

  SubscriptionController(this._prefs) {
    _loadSubscriptions();
    _checkTimer = Timer.periodic(
      const Duration(hours: 1),
      (timer) => checkNewContent(),
    );
  }

  void _loadSubscriptions() {
    final List<String>? subsJson = _prefs.getStringList('subscriptions');
    if (subsJson != null) {
      subscriptions.assignAll(subsJson.map((s) => Subscription.fromJson(s)));
    }
  }

  Future<void> _saveSubscriptions() async {
    final List<String> subsJson = subscriptions.map((s) => s.toJson()).toList();
    await _prefs.setStringList('subscriptions', subsJson);
  }

  Future<void> addSubscription(String url) async {
    final extractionService = Get.find<ExtractionService>();
    final metadata = await extractionService.getMetadata(url);
    if (metadata == null) return;

    final sub = Subscription(
      url: url,
      title: metadata.title,
      lastChecked: DateTime.now(),
      knownVideoIds: metadata.entries.map((e) => e.url).toList(),
    );

    subscriptions.add(sub);
    await _saveSubscriptions();
  }

  Future<void> removeSubscription(String url) async {
    subscriptions.removeWhere((s) => s.url == url);
    await _saveSubscriptions();
  }

  Future<void> checkNewContent() async {
    if (isChecking.value) return;
    isChecking.value = true;
    newDownloadsCount.value = 0;

    final extractionService = Get.find<ExtractionService>();
    final downloadController = Get.find<DownloadController>();

    for (int i = 0; i < subscriptions.length; i++) {
      final sub = subscriptions[i];
      final metadata = await extractionService.getMetadata(sub.url);

      if (metadata != null) {
        final List<String> currentIds = metadata.entries
            .map((e) => e.url)
            .toList();
        final newEntries = metadata.entries
            .where((e) => !sub.knownVideoIds.contains(e.url))
            .toList();

        if (newEntries.isNotEmpty) {
          if (sub.autoDownload) {
            downloadController.downloadBatch(newEntries);
            newDownloadsCount.value += newEntries.length;
          }

          subscriptions[i] = sub.copyWith(
            lastChecked: DateTime.now(),
            knownVideoIds: currentIds,
          );
        } else {
          subscriptions[i] = sub.copyWith(lastChecked: DateTime.now());
        }
      }
    }

    isChecking.value = false;
    await _saveSubscriptions();
  }

  @override
  void onClose() {
    _checkTimer?.cancel();
    super.onClose();
  }
}
