import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Jsonata {
  HeadlessInAppWebView? headlessWebView;
  InAppWebViewController? controller;
  WebViewController? webController;
  Completer<void> webViewCreated = Completer<void>();

  String jql = "";
  String data = "";
  List<dynamic> results = [];
  final Random _random = Random();

  Jsonata([String? jql]) {
    if (jql != null) {
      this.jql = jql.trim();
    }
  }

  void set({dynamic data, dynamic jql}) {
    if (data != null) {
      this.data = data;
    }
    if (jql != null) {
      this.jql = jql;
    }
  }

  Future<Map> query([String? jql]) async {
    if (jql != null) {
      this.jql = jql.trim();
    }
    var result = await evaluate(data);
    return result;
  }

  Future<void> initialize() async {
    String script = await _loadJavaScriptFromAsset();

    if (kIsWeb) {
      // Web Implementation
      webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse("about:blank"))
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (String url) {
            webController!.runJavaScript(script);
          },
        ));
      webViewCreated.complete();
    } else {
      // Mobile/Desktop Implementation
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri("about:blank")),
        onWebViewCreated: (c) {
          controller = c;
          controller!.evaluateJavascript(source: script);
          controller!.evaluateJavascript(source: "initialize($data)");
          controller!.addJavaScriptHandler(
              handlerName: 'json',
              callback: (args) async {
                results.add(args[0]);
              });
          webViewCreated.complete();
        },
        onConsoleMessage: (controller, consoleMessage) {
          print(consoleMessage.message);
        },
      );

      await headlessWebView?.run();
      await webViewCreated.future;
    }
  }

  Future<String> _loadJavaScriptFromAsset() async {
    return await rootBundle.loadString(
        kIsWeb ? 'assets/script.js' : 'packages/jsonata/lib/assets/script.js');
  }

  void dispose() {
    if (kIsWeb) {
      webController = null;
    } else {
      headlessWebView?.dispose();
    }
  }

  Future<Map> evaluate(String data) async {
    this.data = data.trim();
    await initialize();

    const timeoutDuration = Duration(seconds: 10);
    final id = _generateUniqueId();

    try {
      var result = {};
      bool found = false;

      await Future.any([
        () async {
          while (!webViewCreated.isCompleted) {
            await Future.delayed(const Duration(milliseconds: 100));
          }

          if (kIsWeb) {
            // Web implementation using postMessage
            await webController!.runJavaScript(
                "query('$id', '${jql.replaceAll("'", "\"")}')");
          } else {
            // Mobile/Desktop implementation
            await controller!.evaluateJavascript(
                source: "query($id, '${jql.replaceAll("'", "\"")}')");
          }

          while (!found) {
            for (var element in results) {
              if (element.containsKey('id') && element['id'] == id) {
                result = {'value': element['value'], 'error': element['error']};
                found = true;
                results.remove(element);
                break;
              }
            }
            if (!found) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
        }(),
        Future.delayed(timeoutDuration).then((_) {
          if (!found) {
            throw TimeoutException('Query timed out');
          }
        }),
      ]);

      return result;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  int _generateUniqueId() {
    return _random.nextInt(1000000);
  }
}
