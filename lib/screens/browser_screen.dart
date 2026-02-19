import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/cookie_controller.dart';

class BrowserScreen extends StatefulWidget {
  final String initialUrl;
  const BrowserScreen({super.key, this.initialUrl = 'https://www.google.com'});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _urlController.text = url;
            });
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            final cookieController = Get.find<CookieController>();
            await cookieController.extractAndSaveCookies(Uri.parse(url));
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _loadUrl() {
    String url = _urlController.text;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAddressBar(context),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: WebViewWidget(controller: _controller),
          ),
        ),
        _buildControls(context),
      ],
    );
  }

  Widget _buildAddressBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search or enter URL',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _loadUrl(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              if (await _controller.canGoBack()) await _controller.goBack();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () async {
              if (await _controller.canGoForward())
                await _controller.goForward();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cookie_rounded),
            tooltip: 'Capture Cookies',
            onPressed: () async {
              final url = await _controller.currentUrl();
              if (url != null) {
                final cookieController = Get.find<CookieController>();
                await cookieController.extractAndSaveCookies(Uri.parse(url));
                Get.snackbar(
                  'Cookies Captured',
                  'Cookies have been saved for the current site.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () =>
                _controller.loadRequest(Uri.parse('https://www.google.com')),
          ),
        ],
      ),
    );
  }
}
