import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebTestScreen extends StatefulWidget {
  const WebTestScreen({super.key});

  @override
  State<WebTestScreen> createState() => _WebTestScreenState();
}

class _WebTestScreenState extends State<WebTestScreen> {
  final _textController = TextEditingController(text: 'https://');
  late WebViewController _webViewController;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    // 初始化 WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _currentUrl = url;
            });
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入 URL',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    String url = _textController.text.trim();
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    _webViewController.loadRequest(Uri.parse(url));
                    setState(() {
                      _currentUrl = url;
                    });
                  },
                  child: const Text('打开'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _currentUrl == null
                ? const Center(child: Text('请输入 URL 并点击打开'))
                : WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }
}