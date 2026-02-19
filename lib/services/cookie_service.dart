import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CookieService extends ChangeNotifier {
  static final CookieService _instance = CookieService._internal();
  factory CookieService() => _instance;
  CookieService._internal();

  final CookieManager _cookieManager = CookieManager.instance();
  String? _cookieFilePath;

  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    _cookieFilePath = p.join(directory.path, 'cookies.txt');
  }

  String? get cookieFilePath => _cookieFilePath;

  Future<void> extractAndSaveCookies(Uri url) async {
    try {
      final cookies = await _cookieManager.getCookies(url: WebUri.uri(url));
      if (cookies.isEmpty) return;

      final buffer = StringBuffer();
      // Netscape cookie file format (very simplified)
      for (var cookie in cookies) {
        final domain = cookie.domain ?? url.host;
        final name = cookie.name;
        final value = cookie.value;
        final path = cookie.path ?? '/';
        final expiry = cookie.expiresDate != null
            ? (cookie.expiresDate! / 1000).floor()
            : 0;
        final secure = cookie.isSecure ?? false ? 'TRUE' : 'FALSE';

        // Format: domain\tTRUE/FALSE\tpath\tTRUE/FALSE\texpiry\tname\tvalue
        buffer.writeln('$domain\tTRUE\t$path\t$secure\t$expiry\t$name\t$value');
      }

      final file = File(_cookieFilePath!);
      await file.writeAsString(buffer.toString());
      debugPrint('Cookies saved to $_cookieFilePath');
      notifyListeners();
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
    if (_cookieFilePath != null) {
      final file = File(_cookieFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }
}
