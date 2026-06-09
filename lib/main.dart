import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

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
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings));
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const SirDabaApp());
}

Future<void> _requestAllPermissions() async {
  await Permission.notification.request();
  LocationPermission locationPerm = await Geolocator.checkPermission();
  if (locationPerm == LocationPermission.denied) {
    locationPerm = await Geolocator.requestPermission();
  }
  await Permission.camera.request();
  if (await Permission.photos.isDenied) await Permission.photos.request();
  if (await Permission.storage.isDenied) await Permission.storage.request();
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
  return url.startsWith('intent://') ||
      url.startsWith('tel:') ||
      url.startsWith('mailto:') ||
      url.startsWith('whatsapp:') ||
      url.startsWith('geo:') ||
      url.startsWith('maps:') ||
      url.startsWith('comgooglemaps:') ||
      url.contains('maps.app.goo.gl') ||
      url.contains('goo.gl/maps') ||
      url.contains('maps.google.com') ||
      url.contains('google.com/maps') ||
      url.startsWith('market:') ||
      url.startsWith('fb:') ||
      url.startsWith('instagram:') ||
      url.startsWith('twitter:');
}

/// ✅ FIX 3: هل الـ URL ينتمي للموقع الخاص بنا؟
bool _isSiteUrl(String url) {
  return url.startsWith(kSiteUrl) ||
      url.startsWith('https://sirdaba.delivery') ||
      url.startsWith('http://sirdaba.delivery');
}

class SirDabaApp extends StatelessWidget {
  const SirDabaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SirDaba',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFFE8821A))),
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
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _ctrl.forward();

    Future.wait([
      _requestAllPermissions(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]).then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainWebViewScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
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
                  Image.asset('assets/images/logo.png',
                      width: 220, height: 220, fit: BoxFit.contain),
                  const SizedBox(height: 28),
                  const Text('SirDaba Delivery',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE8821A))),
                  const SizedBox(height: 8),
                  const Text('توصيل سريع وموثوق',
                      style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
                  const SizedBox(height: 40),
                  const CircularProgressIndicator(
                      color: Color(0xFFE8821A), strokeWidth: 2.5),
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
  bool _loading = true;
  bool _firstLoad = true;
  String? _fcmToken;
  bool _tokenRegistered = false;
  final ImagePicker _imagePicker = ImagePicker();

  // ✅ FIX 3: timeout لإخفاء الـ spinner إذا ما جاش onPageFinished
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _initFCM();
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 SirDabaApp/1.0 SirDaba-App-Android-Agent')
      ..addJavaScriptChannel('SirDabaFlutter',
          onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          // spinner فقط في أول تحميل
          if (_firstLoad) {
            setState(() => _loading = true);
          }
          // ✅ FIX 3: timeout 15 ثانية — إذا ما كمل التحميل نخفي الـ spinner
          _loadingTimeoutTimer?.cancel();
          _loadingTimeoutTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && _loading) {
              setState(() {
                _loading = false;
                _firstLoad = false;
              });
            }
          });
        },
        onPageFinished: _onPageFinished,
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
          _loadingTimeoutTimer?.cancel();
          setState(() {
            _loading = false;
            _firstLoad = false;
          });
        },
        onNavigationRequest: (request) {
          final url = request.url;

          // external schemes — open outside
          if (_isExternalUrl(url)) {
            _launchExternalUrl(url);
            return NavigationDecision.prevent;
          }
          if (url.startsWith('intent://')) {
            _handleIntentUrl(url);
            return NavigationDecision.prevent;
          }

          // ✅ FIX 3: أي رابط داخل الموقع — نسمح بالتنقل داخل الـ WebView
          // حتى لو جاء من target="_blank" أو window.open
          if (_isSiteUrl(url)) {
            return NavigationDecision.navigate;
          }

          // روابط خارجية كاملة — نفتحها في المتصفح
          if (url.startsWith('http://') || url.startsWith('https://')) {
            _launchExternalUrl(url);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('$kSiteUrl/'));

    final platform = _wvc.platform;
    if (platform is AndroidWebViewController) {
      // ✅ FIX 3: دعم target="_blank" و window.open() — نفتحها داخل نفس الـ WebView
      AndroidWebViewController.enableDebugging(false);
      platform.setOnPlatformPermissionRequest((request) async {
        await Permission.camera.request();
        request.grant();
      });

      // ✅ FIX 3: window.open / target="_blank" → نحمل في نفس الـ WebView
      platform.setOnCreateWindow((request) async {
        final url = request.request.uri.toString();
        if (url.isNotEmpty && _isSiteUrl(url)) {
          _wvc.loadRequest(Uri.parse(url));
        } else if (url.isNotEmpty &&
            (url.startsWith('http://') || url.startsWith('https://'))) {
          _launchExternalUrl(url);
        }
        return false; // false = لا تنشئ WebView جديد
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

          final uri = Uri.file(pickedFile.path).toString();
          return <String>[uri];
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
    return await showModalBottomSheet<ImageSource>(
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

  void _handleIntentUrl(String intentUrl) async {
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

  void _onPageFinished(String url) {
    _loadingTimeoutTimer?.cancel();
    setState(() {
      _loading = false;
      _firstLoad = false;
    });

    _wvc.runJavaScript(r'''
      (function() {
        // ===== Geolocation patch =====
        if (typeof window._sirdabaGeoPatched === 'undefined') {
          window._sirdabaGeoPatched = true;
          if (!navigator.geolocation || !window.isSecureContext) {
            navigator.geolocation = {
              getCurrentPosition: function(success, error, options) {
                window._geoSuccessCallback = success;
                window._geoErrorCallback = error;
                window.SirDabaFlutter.postMessage(JSON.stringify({type: 'get_location'}));
              },
              watchPosition: function(success, error, options) {
                window._geoSuccessCallback = success;
                window._geoErrorCallback = error;
                window.SirDabaFlutter.postMessage(JSON.stringify({type: 'get_location'}));
                return 0;
              },
              clearWatch: function() {}
            };
          }
        }

        // ===== datetime-local patch =====
        if (typeof window._sirdabaDatePatched === 'undefined') {
          window._sirdabaDatePatched = true;

          function patchDateInput(input) {
            if (input._sirdabaPatched) return;
            input._sirdabaPatched = true;
            input.addEventListener('click', function(e) {
              e.preventDefault();
              e.stopPropagation();
              window.SirDabaFlutter.postMessage(JSON.stringify({
                type: 'open_datetime',
                inputId: input.id || '',
                inputName: input.name || '',
                currentValue: input.value || ''
              }));
            }, true);
            input.addEventListener('focus', function(e) {
              e.preventDefault();
              input.blur();
              window.SirDabaFlutter.postMessage(JSON.stringify({
                type: 'open_datetime',
                inputId: input.id || '',
                inputName: input.name || '',
                currentValue: input.value || ''
              }));
            }, true);
          }

          document.querySelectorAll('input[type="datetime-local"]').forEach(patchDateInput);

          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(m) {
              m.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                  if (node.matches && node.matches('input[type="datetime-local"]')) {
                    patchDateInput(node);
                  }
                  if (node.querySelectorAll) {
                    node.querySelectorAll('input[type="datetime-local"]').forEach(patchDateInput);
                  }
                }
              });
            });
          });
          observer.observe(document.body, { childList: true, subtree: true });

          window._sirdabaSetDatetime = function(inputId, inputName, value) {
            var input = null;
            if (inputId) input = document.getElementById(inputId);
            if (!input && inputName) input = document.querySelector('input[name="' + inputName + '"]');
            if (!input) input = document.querySelector('input[type="datetime-local"]');
            if (input) {
              var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
              nativeInputValueSetter.call(input, value);
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
            }
          };
        }

        // ===== App token =====
        var appToken = '';
        var cookies = document.cookie.split(';');
        for (var i = 0; i < cookies.length; i++) {
          var c = cookies[i].trim();
          if (c.startsWith('sirdaba_app_token=')) {
            appToken = c.substring('sirdaba_app_token='.length);
            break;
          }
        }
        if (appToken) {
          window.SirDabaFlutter.postMessage(JSON.stringify({
            type: 'app_token',
            token: decodeURIComponent(appToken)
          }));
        }

        // ===== FIX 3: intercept target=_blank links =====
        if (typeof window._sirdabaLinkPatched === 'undefined') {
          window._sirdabaLinkPatched = true;
          document.addEventListener('click', function(e) {
            var el = e.target;
            while (el && el.tagName !== 'A') el = el.parentElement;
            if (el && el.target === '_blank') {
              var href = el.href;
              if (href && href.startsWith('http')) {
                e.preventDefault();
                window.location.href = href;
              }
            }
          }, true);
        }
      })();
    ''');
  }

  void _onJsMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'app_token') {
        final appToken = data['token'] as String? ?? '';
        if (appToken.isNotEmpty && _fcmToken != null && !_tokenRegistered) {
          _registerFcmTokenWithAuth(_fcmToken!, appToken);
        }
      } else if (type == 'get_location') {
        await _provideLocationToWebView();
      } else if (type == 'open_datetime') {
        await _openDateTimePicker(
          inputId: data['inputId'] as String? ?? '',
          inputName: data['inputName'] as String? ?? '',
          currentValue: data['currentValue'] as String? ?? '',
        );
      }
    } catch (_) {}
  }

  Future<void> _openDateTimePicker({
    required String inputId,
    required String inputName,
    required String currentValue,
  }) async {
    DateTime initialDate = DateTime.now();
    try {
      if (currentValue.isNotEmpty) {
        initialDate = DateTime.parse(currentValue);
      }
    } catch (_) {}

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      // ✅ FIX 4: السماح بتواريخ ماضية (سنة كاملة للخلف)
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE8821A),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE8821A),
              onPrimary: Colors.white,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final formatted =
        '${combined.year.toString().padLeft(4, '0')}-'
        '${combined.month.toString().padLeft(2, '0')}-'
        '${combined.day.toString().padLeft(2, '0')}T'
        '${combined.hour.toString().padLeft(2, '0')}:'
        '${combined.minute.toString().padLeft(2, '0')}';

    final escapedId = inputId.replaceAll("'", "\\'");
    final escapedName = inputName.replaceAll("'", "\\'");
    await _wvc.runJavaScript(
        "window._sirdabaSetDatetime('$escapedId', '$escapedName', '$formatted');");
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
          if (typeof window._geoErrorCallback === 'function') {
            window._geoErrorCallback({code: 1, message: 'Permission denied'});
          }
        ''');
      }
    } catch (e) {
      debugPrint('Location error: $e');
      await _wvc.runJavaScript('''
        if (typeof window._geoErrorCallback === 'function') {
          window._geoErrorCallback({code: 2, message: 'Position unavailable'});
        }
      ''');
    }
  }

  Future<void> _initFCM() async {
    final m = FirebaseMessaging.instance;
    await m.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    final token = await m.getToken();
    if (token != null) await _handleNewToken(token);
    m.onTokenRefresh.listen(_handleNewToken);
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
    final init = await m.getInitialMessage();
    if (init != null) _handleTap(init);
  }

  Future<void> _handleNewToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    _fcmToken = token;
    _tokenRegistered = false;
    await _sendFcmTokenToServer(token);
    try {
      await _wvc.runJavaScript("localStorage.setItem('fcm_token','$token');");
    } catch (_) {}
  }

  Future<void> _registerFcmTokenWithAuth(
      String fcmToken, String appToken) async {
    await _sendFcmTokenToServer(fcmToken);
  }

  Future<void> _sendFcmTokenToServer(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRegistered = prefs.getString('fcm_token_registered') ?? '';
      if (lastRegistered == fcmToken) return;
      final response = await http.post(
        Uri.parse('$kSiteUrl/wp-json/sirdaba/v1/mobile/register-fcm-token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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
    if (url != null) _wvc.loadRequest(Uri.parse(url));
  }

  Future<bool> _onBack() async {
    if (await _wvc.canGoBack()) {
      _wvc.goBack();
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
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8821A), strokeWidth: 2.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
