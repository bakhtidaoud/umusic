import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NetworkService extends GetxService {
  var isConnected = true.obs;
  Timer? _timer;

  Future<NetworkService> init() async {
    _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    return this;
  }

  Future<void> _checkStatus() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (isConnected.value != connected) {
        isConnected.value = connected;
        if (!connected) {
          Get.snackbar(
            'Offline Mode',
            'You are currently offline. Some features may be limited.',
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.BOTTOM,
            icon: const Icon(Icons.wifi_off_rounded, color: Colors.white),
          );
        }
      }
    } catch (_) {
      if (isConnected.value) {
        isConnected.value = false;
        Get.snackbar(
          'Offline Mode',
          'Connection lost.',
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
