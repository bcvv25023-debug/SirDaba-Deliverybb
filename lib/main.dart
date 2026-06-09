import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'sirdaba_high_importance',
  'SirDaba Notifications',
  description: 'اشعارات SirDaba',
  importance: Importance.max,
  playSound: true,
);

const String kSiteUrl = 'https://sirdaba.delivery';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const SirDabaApp());
}

Future<void> _requestAllPermissions() async {
  await Permission.notification.request();
  await Permission.camera.request();

  if (Platform.isAndroid) {
    await Permission.storage.request();
  }

  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }

  LocationPermission locationPerm = await Geolocator.checkPermission();
  if (locationPerm == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }
}

Future<void> _launchExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Launch error: $e');
  }
}

bool _isExternalUrl(String url) {
  final lower = url.toLowerCase();

  return lower.startsWith('intent://') ||
      lower.startsWith('tel:') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('sms:') ||
      lower.startsWith('whatsapp:') ||
      lower.startsWith('geo:') ||
      lower.startsWith('maps:') ||
      lower.startsWith('comgooglemaps:') ||
      lower.startsWith('market:') ||
      lower.startsWith('fb:') ||
      lower.startsWith('instagram:') ||
      lower.startsWith('twitter:') ||
      lower.startsWith('tg:') ||
      lower.startsWith('snapchat:') ||
      lower.contains('maps.app.goo.gl') ||
      lower.contains('goo.gl/maps') ||
      lower.contains('maps.google.com') ||
      lower.contains('google.com/maps');
}

bool _isInternalUrl(String url) {
  try {
    final uri = Uri.parse(url);
    if (url == 'about:blank') return true;
    if (uri.scheme == 'data' || uri.scheme == 'blob') return true;
    final host = uri.host.toLowerCase();
    return host == 'sirdaba.delivery' || host.endsWith('.sirdaba.delivery');
  } catch (_) {
    return false;
  }
}

class SirDabaApp extends StatelessWidget {
  const SirDabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SirDaba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8821A)),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();

    Future.wait([
      _requestAllPermissions(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]).then((_) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainWebViewScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'SirDaba Delivery',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE8821A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'توصيل سريع وموثوق',
                    style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(
                    color: Color(0xFFE8821A),
                    strokeWidth: 2.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainWebViewScreen extends StatefulWidget {
  const MainWebViewScreen({super.key});

  @override
  State<MainWebViewScreen> createState() => _MainWebViewScreenState();
}

class _MainWebViewScreenState extends State<MainWebViewScreen> {
  late final WebViewController _wvc;
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  int _progress = 0;
  String? _fcmToken;
  bool _tokenRegistered = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _initFCM();
  }

  void _initWebView() {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
        'SirDabaApp/1.1 SirDaba-App-Android-Agent',
      )
      ..addJavaScriptChannel(
        'SirDabaFlutter',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _loading = progress < 100;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _loading = true);
          },
          onPageFinished: _onPageFinished,
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            if (_isExternalUrl(url)) {
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            if (url.startsWith('intent://')) {
              _handleIntentUrl(url);
              return NavigationDecision.prevent;
            }

            if (_isInternalUrl(url)) {
              return NavigationDecision.navigate;
            }

            if (url.startsWith('http://') || url.startsWith('https://')) {
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..setOnConsoleMessage((msg) {
        debugPrint('WebView console: ${msg.message}');
      })
      ..loadRequest(Uri.parse('$kSiteUrl/'));

    final platform = _wvc.platform;

    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      platform.setMediaPlaybackRequiresUserGesture(false);

      platform.setOnPlatformPermissionRequest((request) async {
        await Permission.camera.request();
        await Permission.microphone.request();
        request.grant();
      });

      platform.setOnShowFileSelector((params) async {
        try {
          await Permission.photos.request();
          await Permission.storage.request();

          final source = await _showImageSourceDialog();
          if (source == null) return const <String>[];

          XFile? pickedFile;

          if (source == ImageSource.camera) {
            await Permission.camera.request();
            pickedFile = await _imagePicker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
            );
          } else {
            pickedFile = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
          }

          if (pickedFile == null) return const <String>[];
          return <String>[Uri.file(pickedFile.path).toString()];
        } catch (e) {
          debugPrint('File selector error: $e');
          return const <String>[];
        }
      });

      platform.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied ||
              perm == LocationPermission.deniedForever) {
            perm = await Geolocator.requestPermission();
          }

          final granted = perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse;

          return GeolocationPermissionsResponse(
            allow: granted,
            retain: granted,
          );
        },
        onHidePrompt: () {},
      );
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر مصدر الصورة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFE8821A)),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFE8821A)),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleIntentUrl(String intentUrl) async {
    try {
      final fallbackMatch =
          RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(intentUrl);

      if (fallbackMatch != null) {
        final fallback = Uri.decodeComponent(fallbackMatch.group(1) ?? '');
        if (fallback.isNotEmpty) {
          await _launchExternalUrl(fallback);
          return;
        }
      }

      final converted = intentUrl
          .replaceFirst('intent://', 'https://')
          .split(';')[0]
          .split('#')[0];

      await _launchExternalUrl(converted);
    } catch (e) {
      debugPrint('Intent URL error: $e');
    }
  }

  String _buildInjectedJs() {
    return '''
(function() {
  if (window.__sirdabaPatched === true) {
    try { if (window.__sirdabaPatchDynamic) window.__sirdabaPatchDynamic(); } catch (e) {}
    return;
  }

  window.__sirdabaPatched = true;

  function postMessage(payload) {
    try {
      SirDabaFlutter.postMessage(JSON.stringify(payload));
    } catch (e) {}
  }

  function sameTabNavigate(url) {
    if (!url || url === 'about:blank') return;
    try {
      window.location.assign(url);
    } catch (e) {
      try { window.location.href = url; } catch (_) {}
    }
  }

  function createFakeWindow() {
    var loc = {
      assign: function(url) { sameTabNavigate(url); },
      replace: function(url) { sameTabNavigate(url); }
    };

    Object.defineProperty(loc, 'href', {
      configurable: true,
      enumerable: true,
      get: function() { return window.location.href; },
      set: function(value) { sameTabNavigate(value); }
    });

    return {
      closed: false,
      opener: window,
      focus: function() {},
      blur: function() {},
      close: function() {},
      postMessage: function() {},
      location: loc
    };
  }

  window.open = function(url, target, features) {
    var fake = createFakeWindow();
    if (url && url !== '' && url !== 'about:blank') {
      sameTabNavigate(url);
    }
    return fake;
  };

  function patchLinksAndForms(root) {
    root = root || document;

    try {
      root.querySelectorAll('a[target="_blank"]').forEach(function(a) {
        if (a.dataset.sdBlankPatched === '1') return;
        a.dataset.sdBlankPatched = '1';
        a.target = '_self';
        a.addEventListener('click', function(e) {
          if (a.href && a.href !== 'javascript:void(0);' && a.href !== '#') {
            e.preventDefault();
            sameTabNavigate(a.href);
          }
        }, true);
      });
    } catch (e) {}

    try {
      root.querySelectorAll('form[target="_blank"]').forEach(function(form) {
        form.target = '_self';
      });
    } catch (e) {}

    try {
      root.querySelectorAll('[data-href]').forEach(function(el) {
        if (el.dataset.sdHrefPatched === '1') return;
        el.dataset.sdHrefPatched = '1';
        el.addEventListener('click', function() {
          var url = el.getAttribute('data-href');
          if (url) sameTabNavigate(url);
        }, true);
      });
    } catch (e) {}
  }

  window.__sirdabaPatchDynamic = patchLinksAndForms;
  patchLinksAndForms(document);

  try {
    var observer = new MutationObserver(function() {
      patchLinksAndForms(document);
    });
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true
    });
  } catch (e) {}

  try {
    if (!navigator.geolocation || !window.isSecureContext) {
      navigator.geolocation = {
        getCurrentPosition: function(success, error, options) {
          window._geoSuccessCallback = success;
          window._geoErrorCallback = error;
          postMessage({ type: 'get_location' });
        },
        watchPosition: function(success, error, options) {
          window._geoSuccessCallback = success;
          window._geoErrorCallback = error;
          postMessage({ type: 'get_location' });
          return 1;
        },
        clearWatch: function() {}
      };
    }
  } catch (e) {}

  function findAppToken() {
    var token = '';
    var candidateKeys = ['app_token', 'token', 'auth_token', 'jwt', 'access_token'];

    try {
      var cookies = document.cookie.split(';');
      for (var i = 0; i < cookies.length; i++) {
        var part = cookies[i].trim();
        var eq = part.indexOf('=');
        if (eq === -1) continue;
        var key = part.substring(0, eq).trim();
        var value = part.substring(eq + 1).trim();
        if (candidateKeys.indexOf(key) !== -1 && value) {
          token = decodeURIComponent(value);
          break;
        }
      }
    } catch (e) {}

    if (!token) {
      try {
        for (var j = 0; j < candidateKeys.length; j++) {
          var k = candidateKeys[j];
          token = localStorage.getItem(k) || sessionStorage.getItem(k) || '';
          if (token) break;
        }
      } catch (e) {}
    }

    if (token) {
      postMessage({ type: 'app_token', token: token });
    }
  }

  try {
    findAppToken();
    setTimeout(findAppToken, 1200);
    setTimeout(findAppToken, 2500);
  } catch (e) {}
})();
''';
  }

  Future<void> _injectWebFixes() async {
    try {
      await _wvc.runJavaScript(_buildInjectedJs());
      if (_fcmToken != null) {
        final safeToken = jsonEncode(_fcmToken!);
        await _wvc.runJavaScript(
          "try { localStorage.setItem('fcm_token', $safeToken); } catch (e) {}",
        );
      }
    } catch (e) {
      debugPrint('Injection error: $e');
    }
  }

  void _onPageFinished(String url) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _progress = 100;
    });

    _injectWebFixes();
    Future.delayed(const Duration(milliseconds: 500), _injectWebFixes);
    Future.delayed(const Duration(milliseconds: 1500), _injectWebFixes);
  }

  Future<void> _onJsMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'app_token') {
        final appToken = data['token'] as String? ?? '';
        if (appToken.isNotEmpty && _fcmToken != null && !_tokenRegistered) {
          await _registerFcmTokenWithAuth(_fcmToken!, appToken);
        }
      } else if (type == 'get_location') {
        await _provideLocationToWebView();
      }
    } catch (e) {
      debugPrint('JS message parse error: $e');
    }
  }

  Future<void> _provideLocationToWebView() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );

        await _wvc.runJavaScript('''
          (function() {
            if (typeof window._geoSuccessCallback === 'function') {
              window._geoSuccessCallback({
                coords: {
                  latitude: ${pos.latitude},
                  longitude: ${pos.longitude},
                  accuracy: ${pos.accuracy},
                  altitude: ${pos.altitude},
                  altitudeAccuracy: null,
                  heading: null,
                  speed: null
                },
                timestamp: ${pos.timestamp.millisecondsSinceEpoch}
              });
            }
          })();
        ''');
      } else {
        await _wvc.runJavaScript('''
          (function() {
            if (typeof window._geoErrorCallback === 'function') {
              window._geoErrorCallback({code: 1, message: 'Permission denied'});
            }
          })();
        ''');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      await _wvc.runJavaScript('''
        (function() {
          if (typeof window._geoErrorCallback === 'function') {
            window._geoErrorCallback({code: 2, message: 'Position unavailable'});
          }
        })();
      ''');
    }
  }

  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final token = await messaging.getToken();
    if (token != null) {
      await _handleNewToken(token);
    }

    messaging.onTokenRefresh.listen(_handleNewToken);

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        flutterLocalNotificationsPlugin.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(initialMessage);
    }
  }

  Future<void> _handleNewToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);

    _fcmToken = token;
    _tokenRegistered = false;

    await _sendFcmTokenToServer(token);

    try {
      final safeToken = jsonEncode(token);
      await _wvc.runJavaScript(
        "try { localStorage.setItem('fcm_token', $safeToken); } catch (e) {}",
      );
    } catch (_) {}
  }

  Future<void> _registerFcmTokenWithAuth(
    String fcmToken,
    String appToken,
  ) async {
    await _sendFcmTokenToServer(fcmToken, appToken: appToken);
  }

  Future<void> _sendFcmTokenToServer(
    String fcmToken, {
    String? appToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRegistered = prefs.getString('fcm_token_registered') ?? '';
      if (lastRegistered == fcmToken) return;

      final headers = <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      if (appToken != null && appToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $appToken';
      }

      final response = await http.post(
        Uri.parse('$kSiteUrl/wp-json/sirdaba/v1/mobile/register-fcm-token'),
        headers: headers,
        body: {
          'fcm_token': fcmToken,
          'platform': 'android',
        },
      );

      if (response.statusCode == 200) {
        _tokenRegistered = true;
        await prefs.setString('fcm_token_registered', fcmToken);
        debugPrint('FCM token registered ✅');
      } else {
        debugPrint('FCM register failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FCM register error: $e');
    }
  }

  void _handleTap(RemoteMessage msg) {
    final url = msg.data['url'] ?? msg.data['link'];
    if (url == null) return;

    final parsed = Uri.tryParse(url.toString());
    if (parsed != null) {
      _wvc.loadRequest(parsed);
    }
  }

  Future<bool> _onBack() async {
    if (await _wvc.canGoBack()) {
      await _wvc.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _wvc),
              if (_loading)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFE8821A),
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _progress > 0 && _progress < 100
                              ? '$_progress%'
                              : 'جاري التحميل...',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
