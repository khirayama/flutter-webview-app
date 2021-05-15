import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '././webviewmessage.dart';

void main() => runApp(MaterialApp(home:WebView()));

class WebView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  WebViewController _controller;

  Location _location = new Location();

  List _locations = [];

  StreamSubscription<LocationData> _locationSubscription;

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
            initialUrl: 'http://10.0.2.2:3000',
            onWebViewCreated: (WebViewController webViewController) async {
              _controller = webViewController;
              // await _loadHtmlFromAssets();
            },
            javascriptMode: JavascriptMode.unrestricted,
            javascriptChannels: Set.from([
              onMessageReceived((dynamic payload) async {
                if (payload['type'] == 'startlogging') {
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

                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  _location.enableBackgroundMode(enable: true);
                  _locationSubscription =_location.onLocationChanged.listen((LocationData currentLocation) {
                    _locations.add({
                      'timestamp': currentLocation.time,
                      'coords': {
                        'accuracy': currentLocation.accuracy,
                        'altitude': currentLocation.altitude,
                        'altitudeAccuracy': null,
                        'heading': currentLocation.heading,
                        'latitude': currentLocation.latitude,
                        'longitude': currentLocation.longitude,
                        'speed': currentLocation.speed,
                      },
                    });
                    prefs.setString('_locations', jsonEncode(_locations));
                    postMessage(_controller, {
                      'type': 'locationchange',
                      'payload': {
                        'locations': _locations,
                      },
                    });
                  });
                } else if (payload['type'] == 'stoplogging') {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  _locationSubscription.cancel();
                  print('TODO: Save locations');
                  _locations = [];
                  prefs.remove('_locations');
                } else if (payload['type'] == 'getlocations') {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  _locations = jsonDecode(prefs.getString('_locations'));
                  postMessage(_controller, {
                    'type': 'locationchange',
                    'payload': {
                      'locations': _locations,
                    },
                  });
                }
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
