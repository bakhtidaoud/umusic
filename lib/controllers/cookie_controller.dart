import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CookieController extends GetxController {
  final CookieManager _cookieManager = CookieManager.instance();
  var cookieFilePath = RxnString();

  @override
  void onInit() {
    super.onInit();
    init();
  }

  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    cookieFilePath.value = p.join(directory.path, 'cookies.txt');
  }

  Future<void> extractAndSaveCookies(Uri url) async {
    try {
      final cookies = await _cookieManager.getCookies(url: WebUri.uri(url));
      if (cookies.isEmpty) return;

      final buffer = StringBuffer();
      for (var cookie in cookies) {
        final domain = cookie.domain ?? url.host;
        final name = cookie.name;
        final value = cookie.value;
        final path = cookie.path ?? '/';
        final expiry = cookie.expiresDate != null
            ? (cookie.expiresDate! / 1000).floor()
            : 0;
        final secure = cookie.isSecure ?? false ? 'TRUE' : 'FALSE';

        buffer.writeln('$domain\tTRUE\t$path\t$secure\t$expiry\t$name\t$value');
      }

      final file = File(cookieFilePath.value!);
      await file.writeAsString(buffer.toString());
      debugPrint('Cookies saved to ${cookieFilePath.value}');
    } catch (e) {
      debugPrint('Error saving cookies: $e');
    }
  }

  Future<String?> getCookieString(Uri url) async {
    final cookies = await _cookieManager.getCookies(url: WebUri.uri(url));
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  Future<void> clearCookies() async {
    await _cookieManager.deleteAllCookies();
    if (cookieFilePath.value != null) {
      final file = File(cookieFilePath.value!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
