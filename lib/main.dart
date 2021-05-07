import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';


List locations = [];

void main() => runApp(MaterialApp(home:WebViewExample()));

class WebViewExample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  WebViewController _controller;

  Location _location;

  bool _serviceEnabled;

  PermissionStatus _permissionGranted;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _backButton(context),
      child: Scaffold(
        body: SafeArea(
          child: WebView(
            // initialUrl: 'https://youtube.com',
            onWebViewCreated: (WebViewController webViewController) async {
              _controller = webViewController;
              await _loadHtmlFromAssets();

              _location = new Location();

              _serviceEnabled = await _location.serviceEnabled();
              if (!_serviceEnabled) {
                _serviceEnabled = await _location.requestService();
                if (!_serviceEnabled) {
                  return;
                }
              }
              _permissionGranted = await _location.hasPermission();
              if (_permissionGranted == PermissionStatus.denied) {
                _permissionGranted = await _location.requestPermission();
                if (_permissionGranted != PermissionStatus.granted) {
                  return;
                }
              }

              _location.enableBackgroundMode(enable: true);
              _location.onLocationChanged.listen((LocationData currentLocation) {
                locations.add({
                  'lat': currentLocation.latitude,
                  'lon': currentLocation.longitude,
                  'alt': currentLocation.altitude,
                  'time': currentLocation.time,
                });
                // LocationData _locationData = await _location.getLocation();
                postMessage(_controller, {
                  'type': 'locationchange',
                  'payload': {
                    'locations': locations,
                  },
                });
              });
            },
            javascriptMode: JavascriptMode.unrestricted,
            javascriptChannels: Set.from([
              onMessageReceived((dynamic payload) {
                print(payload['text']);
              }),
            ]),
          )
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: onPressFloatingActionButton,
        ),
      )
    );
  }

  void onPressFloatingActionButton() async {
    postMessage(_controller, { 'message': 'Hello World from Flutter' });
  }

  Future _loadHtmlFromAssets() async {
    String fileText = await rootBundle.loadString('assets/index.html');
    await _controller.loadUrl( Uri.dataFromString(
            fileText,
            mimeType: 'text/html',
            encoding: Encoding.getByName('utf-8')
    ).toString());
  }

  Future _backButton(BuildContext context) async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      SystemNavigator.pop();
    }
  }       
}

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
