import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

JavascriptChannel onMessageReceived(Function callback) {
  return JavascriptChannel(
      name: "app",
      onMessageReceived: (JavascriptMessage event) {
        var payload = jsonDecode(event.message);
        callback(payload);
      },
  );
}

void postMessage(WebViewController webViewController, dynamic payload) {
  webViewController.evaluateJavascript('''
      window.dispatchEvent(new CustomEvent("app:message", { detail: ${jsonEncode(payload)}}));
      ''');
}
