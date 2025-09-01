import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/service_locator.dart';

class WertDepositScreen extends StatefulWidget {
  final String sessionId;
  const WertDepositScreen({super.key, required this.sessionId});

  @override
  State<WertDepositScreen> createState() => _WertDepositScreenState();
}

class _WertDepositScreenState extends State<WertDepositScreen> {
  late final WebViewController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    final wert = ServiceLocator().wertService;
    final redirectUrl = wert.redirectUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0b0f14))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Intercept redirect to configured URL → close and refresh portfolio
            if (request.url.startsWith(redirectUrl)) {
              developer.log('Wert redirect detected → closing and refreshing portfolio', name: 'wert');
              // Cancel navigation and pop
              _onWertFinished();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            if (!_initialized && url.contains('assets/wert/wert_widget.html')) {
              _initialized = true;
              await _initWidget();
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/wert/wert_widget.html');
  }

  Future<void> _initWidget() async {
    try {
      final wert = ServiceLocator().wertService;
      final partnerId = wert.partnerId;
      final origin = wert.widgetOrigin;
      final redirectUrl = wert.redirectUrl;

      final js = "initWert('${widget.sessionId}', '$partnerId', '$origin', '$redirectUrl');";
      developer.log('Injecting Wert init JS', name: 'wert');
      await _controller.runJavaScript(js);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to initialize Wert: $e')));
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _onWertFinished() async {
    if (!mounted) return;
    try {
      await ServiceLocator().portfolioAdapter.refreshPortfolio();
    } catch (e) {
      developer.log('Portfolio refresh after Wert failed: $e', name: 'wert');
    }
    if (mounted) Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit USDT'),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
