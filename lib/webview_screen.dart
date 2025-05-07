import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  bool _isLoading = true;
  double _progress = 0.0;
  bool isInitialPageLoaded = false;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final String initialUrl = 'https://app.goexdata.com';

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () async {
        await _webViewController?.reload();
      },
    );
    _requestPermissions();
    _initDeepLinks();
    _setupForegroundNotifications();
    _requestLocation();

    _webViewController?.addJavaScriptHandler(
      handlerName: 'uploadMedia',
      callback: (args) {
        if (args.isNotEmpty) {
          _handleMediaUpload(args[0]);
        }
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('link') && _webViewController != null) {
        _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(message.data['link'])),
        );
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.camera.request();
      await Permission.photos.request();
      await Permission.location.request();
    }
    if (Platform.isIOS) {
      await Permission.camera.request();
      await Permission.photos.request();
      await Permission.location.request();

      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _injectViewportFix() async {
    final currentUrl = (await _webViewController?.getUrl())?.toString() ?? '';
    await _webViewController?.evaluateJavascript(source: '''
    (function() {

      var existingMeta = document.querySelector('meta[name="viewport"]');
      if (existingMeta) existingMeta.remove();

      var meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
      document.head.appendChild(meta);

      var currentUrl = "$currentUrl"; 
      var style = document.createElement('style');
      if (!currentUrl.includes('/signup')) { 
        style.innerHTML = `
          html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow-x: hidden;
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
            background: #fff;
            position: relative;
          }
          body {
            padding-top: env(safe-area-inset-top, 0px);
            padding-bottom: env(safe-area-inset-bottom, 0px);
            padding-left: env(safe-area-inset-left, 0px);
            padding-right: env(safe-area-inset-right, 0px);
          }
          main, .main, [role="main"] {
            margin-top: env(safe-area-inset-top, 0px);
            padding-top: calc(env(safe-area-inset-top, 0px) + 60px);
            min-height: 100vh;
            width: 100%;
            box-sizing: border-box;
            overflow-x: hidden;
          }
        `;
        document.head.appendChild(style);
      }

      // Force re-render to apply changes
      window.dispatchEvent(new Event('resize'));
    })();
  ''');
  }

  Future<void> _requestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Location permissions are permanently denied. Please enable in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _webViewController?.evaluateJavascript(
        source:
            'window.postMessage({ type: "location", latitude: ${position.latitude}, longitude: ${position.longitude}, accuracy: ${position.accuracy} }, "*");',
      );
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();


    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri.toString());
    }, onError: (err) {
      print('Error in link stream: $err');
    });
  }

  void _handleDeepLink(String link) {
    if (_webViewController != null) {
      _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
    }
  }

  void _setupForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${message.notification!.title}: ${message.notification!.body}'),
            action: message.data.containsKey('link')
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () {
                      if (_webViewController != null) {
                        _webViewController!.loadUrl(
                          urlRequest:
                              URLRequest(url: WebUri(message.data['link'])),
                        );
                      }
                    },
                  )
                : null,
          ),
        );
        if (_webViewController != null) {
          _webViewController!.evaluateJavascript(
            source: 'window.postMessage(${jsonEncode(message.data)}, "*");',
          );
        }
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final currentUrl = (await _webViewController!.getUrl())?.toString() ?? '';

      debugPrint('Back button pressed. Can go back: $canGoBack');
      debugPrint('Current URL: $currentUrl');

      if (canGoBack && currentUrl != initialUrl) {
        _webViewController!.goBack();
        return false;
      } else {
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          debugPrint('User confirmed exit.');
        } else {
          debugPrint('User cancelled exit.');
        }
        return shouldExit;
      }
    }
    return true;
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit?"),
            content: const Text("Are you sure you want to exit the app?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text("Exit"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _isDownloadable(String url) {
    return url.endsWith('.pdf') ||
        url.endsWith('.doc') ||
        url.endsWith('.docx') ||
        url.endsWith('.xls') ||
        url.endsWith('.xlsx');
  }

  Future<void> _handleMediaUpload(String type) async {
    try {
      if (type == 'camera') {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.camera);
        if (image != null) {
          _webViewController?.evaluateJavascript(
            source:
                'window.postMessage({ type: "media", path: "${image.path}" }, "*");',
          );
        }
      } else if (type == 'gallery') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.media,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          _webViewController?.evaluateJavascript(
            source:
                'window.postMessage({ type: "media", path: "${result.files.single.path}" }, "*");',
          );
        }
      }
    } catch (e) {
      print('Media upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading media: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: SafeArea(
        top: true,
        bottom: true,
        child: Scaffold(
          body: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useOnDownloadStart: true,
                  useShouldOverrideUrlLoading: true,
                  useHybridComposition: true,
                  allowsInlineMediaPlayback: true,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  supportZoom: false,
                  disableVerticalScroll: false,
                  disableHorizontalScroll: false,
                  isPagingEnabled: false,
                  transparentBackground: false,
                  cacheEnabled: true,
                  overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsBackForwardNavigationGestures: true,
                  allowsLinkPreview: false,
                  disableContextMenu: false,
                  disableLongPressContextMenuOnLinks: false,
                  useShouldInterceptAjaxRequest: true,
                  useShouldInterceptFetchRequest: true,
                  useOnLoadResource: true,
                  safeBrowsingEnabled: true,
                  forceDark: ForceDark.AUTO,
                ),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (_, __) => setState(() {
                  _isLoading = true;
                  _progress = 0.0;
                }),
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100.0;
                  });
                },
                onLoadStop: (controller, url) async {
                  final loadedUrl = url.toString();
                  debugPrint('Page loaded: $loadedUrl');
                  isInitialPageLoaded = (loadedUrl == initialUrl);
                  debugPrint('Is initial page: $isInitialPageLoaded');
                  setState(() {
                    _isLoading = false;
                    _progress = 1.0;
                  });
                  await _injectViewportFix();
                },
                onUpdateVisitedHistory:
                    (controller, url, androidIsReload) async {
                  await _injectViewportFix();
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print('WebView Console: ${consoleMessage.message}');
                },
                onReceivedError: (controller, request, error) {
                  if (mounted) {
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   SnackBar(
                    //       content: Text('WebView Error: ${error.description}')),
                    // );
                  }
                  setState(() {
                    _isLoading = false;
                    _progress = 1.0;
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url.toString();
                  if (_isDownloadable(url)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download started: $url')),
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onDownloadStartRequest: (controller, downloadRequest) async {
                  final url = downloadRequest.url.toString();
                  if (_isDownloadable(url)) {
                    try {
                      final response = await http.get(Uri.parse(url));
                      final dir = await getTemporaryDirectory();
                      final fileName = url.split('/').last;
                      final file = File('${dir.path}/$fileName');
                      await file.writeAsBytes(response.bodyBytes);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Downloaded: $fileName'),
                          action: SnackBarAction(
                            label: 'Open',
                            onPressed: () {
                              OpenFile.open(file.path);
                            },
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Download failed: $e')),
                      );
                    }
                  }
                },
              ),
              if (_isLoading)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white,
                  color: const Color.fromARGB(255, 16, 7, 70),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _pullToRefreshController?.dispose();
    super.dispose();
  }
}
