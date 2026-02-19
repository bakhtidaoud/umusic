import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../services/cookie_service.dart';

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
            // Capture cookies on page finish
            final cookieService = Provider.of<CookieService>(
              context,
              listen: false,
            );
            final uri = Uri.parse(url);
            await cookieService.extractAndSaveCookies(uri);
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'Search or enter URL',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _loadUrl(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.cookie),
            tooltip: 'Capture Cookies Now',
            onPressed: () async {
              final url = await _controller.currentUrl();
              if (url != null) {
                final cookieService = Provider.of<CookieService>(
                  context,
                  listen: false,
                );
                await cookieService.extractAndSaveCookies(Uri.parse(url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cookies captured and saved!'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () =>
                  _controller.loadRequest(Uri.parse('https://www.google.com')),
            ),
          ],
        ),
      ),
    );
  }
}
