import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import '../controllers/cookie_controller.dart';
import '../controllers/home_controller.dart';

class LoginWebViewScreen extends StatefulWidget {
  final String initialUrl;
  const LoginWebViewScreen({super.key, required this.initialUrl});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final cookieController = Get.find<CookieController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_webViewController != null) {
                final currentUrl = await _webViewController!.getUrl();
                if (currentUrl != null) {
                  await cookieController.extractAndSaveCookies(currentUrl);

                  // Refresh videos on home screen after login
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().fetchVideos();
                  }

                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              setState(() => _isLoading = false);
              if (url != null) {
                await cookieController.extractAndSaveCookies(url);
                // Trigger refresh if we reached a successful login state (optional but helpful)
                if (url.toString().contains('youtube.com') &&
                    !url.toString().contains('ServiceLogin')) {
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().fetchVideos();
                  }
                }
              }
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
