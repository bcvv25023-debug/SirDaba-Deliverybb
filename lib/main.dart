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
const String kHomeUrl = '$kSiteUrl/';
const String kLoginUrl = '$kSiteUrl/';
const String kClientUrl = '$kSiteUrl/sirdaba-client/';
const String kDistributorUrl = '$kSiteUrl/sirdaba-distributor/';
const String kAppStatusUrl = '$kSiteUrl/wp-json/sirdaba/v1/mobile/app-status';
const String kPrefIsLoggedOut = 'sirdaba_is_logged_out';

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

Future<String> _resolveInitialUrl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedOut = prefs.getBool(kPrefIsLoggedOut) ?? false;
    if (isLoggedOut) return kHomeUrl;
    final response = await http.get(
      Uri.parse(kAppStatusUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 SirDabaApp/1.0 SirDaba-App-Android-Agent',
      },
    ).timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final loggedIn = data['logged_in'] == true;
      final dashboardUrl = data['dashboard_url'] as String? ?? '';
      final userType = data['user_type'] as String? ?? '';
      if (loggedIn && dashboardUrl.isNotEmpty) {
        return dashboardUrl.endsWith('/') ? dashboardUrl : '$dashboardUrl/';
      }
      if (loggedIn) {
        return userType == 'distributor' ? kDistributorUrl : kClientUrl;
      }
    }
  } catch (e) {
    debugPrint('app-status check failed: $e');
  }
  return kHomeUrl;
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
      supportedLocales: const [Locale('ar'), Locale('en')],
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
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _ctrl.forward();
    Future.wait([
      _requestAllPermissions(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]).then((_) async {
      if (!mounted) return;
      final initialUrl = await _resolveInitialUrl();
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              MainWebViewScreen(initialUrl: initialUrl),
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
  final String initialUrl;
  const MainWebViewScreen({super.key, this.initialUrl = kHomeUrl});
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
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 SirDabaApp/1.0 SirDaba-App-Android-Agent')
      ..addJavaScriptChannel('SirDabaFlutter',
          onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (_firstLoad) setState(() => _loading = true);
        },
        onPageFinished: _onPageFinished,
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
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
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));

    final platform = _wvc.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      platform.setMediaPlaybackRequiresUserGesture(false);

      platform.setOnPlatformPermissionRequest((request) async {
        await Permission.camera.request();
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
                source: ImageSource.camera, imageQuality: 85);
          } else {
            pickedFile = await _imagePicker.pickImage(
                source: ImageSource.gallery, imageQuality: 85);
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
              allow: granted, retain: granted);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('اختر مصدر الصورة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFE8821A)),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFFE8821A)),
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
    setState(() {
      _loading = false;
      _firstLoad = false;
    });

    _wvc.runJavaScript(r'''
(function() {
  function fixLeaflet() {
    if (typeof L !== 'undefined') {
      try {
        L.Browser.touch = true;
        L.Browser.pointer = false;
        L.Browser.mobile = true;
        L.Browser.mobileWebkit = true;
        L.Browser.mobileWebkit3d = true;
      } catch(e) {}
    }
    document.querySelectorAll('.leaflet-container').forEach(function(el) {
      el.style.touchAction = 'none';
      el.style.userSelect = 'none';
      el.style.webkitUserSelect = 'none';
      el.style.cursor = 'grab';
    });
  }
  fixLeaflet();
  setTimeout(fixLeaflet, 500);
  setTimeout(fixLeaflet, 1500);
  setTimeout(fixLeaflet, 3000);
  var leafletObserver = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType === 1) {
          if ((node.classList && node.classList.contains('leaflet-container')) ||
              (node.querySelector && node.querySelector('.leaflet-container'))) {
            setTimeout(fixLeaflet, 100);
          }
        }
      });
    });
  });
  if (document.body) {
    leafletObserver.observe(document.body, { childList: true, subtree: true });
  }
})();
''');

    _wvc.runJavaScript(r'''
(function() {
  if (typeof window._sirdabaGeoPatched === 'undefined') {
    window._sirdabaGeoPatched = true;
    if (!navigator.geolocation || !window.isSecureContext) {
      navigator.geolocation = {
        getCurrentPosition: function(success, error, options) {
          window._geoSuccessCallback = success;
          window._geoErrorCallback = error;
          window.SirDabaFlutter.postMessage(JSON.stringify({type:'get_location'}));
        },
        watchPosition: function(success, error, options) {
          window._geoSuccessCallback = success;
          window._geoErrorCallback = error;
          window.SirDabaFlutter.postMessage(JSON.stringify({type:'get_location'}));
          return 0;
        },
        clearWatch: function() {}
      };
    }
  }

  if (typeof window._sirdabaDatePatched === 'undefined') {
    window._sirdabaDatePatched = true;
    function patchDateInput(input) {
      if (input._sirdabaPatched) return;
      input._sirdabaPatched = true;
      var _opening = false;
      function openPicker(e) {
        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
        if (_opening) return;
        _opening = true;
        setTimeout(function() { _opening = false; }, 800);
        input.blur();
        window.SirDabaFlutter.postMessage(JSON.stringify({
          type:'open_datetime', inputId:input.id||'', inputName:input.name||'', currentValue:input.value||''
        }));
      }
      input.addEventListener('mousedown',function(e){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();return false;},true);
      input.addEventListener('touchstart',function(e){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();return false;},true);
      input.addEventListener('click',openPicker,true);
      input.addEventListener('focus',function(e){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();input.blur();return false;},true);
    }
    document.querySelectorAll('input[type="datetime-local"]').forEach(patchDateInput);
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(m) {
        m.addedNodes.forEach(function(node) {
          if (node.nodeType===1) {
            if (node.matches&&node.matches('input[type="datetime-local"]')) patchDateInput(node);
            if (node.querySelectorAll) node.querySelectorAll('input[type="datetime-local"]').forEach(patchDateInput);
          }
        });
      });
    });
    observer.observe(document.body,{childList:true,subtree:true});
    window._sirdabaSetDatetime = function(inputId,inputName,value) {
      var input=null;
      if (inputId) input=document.getElementById(inputId);
      if (!input&&inputName) input=document.querySelector('input[name="'+inputName+'"]');
      if (!input) input=document.querySelector('input[type="datetime-local"]');
      if (input) {
        var setter=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
        setter.call(input,value);
        input.dispatchEvent(new Event('input',{bubbles:true}));
        input.dispatchEvent(new Event('change',{bubbles:true}));
      }
    };
  }

  var appToken='';
  document.cookie.split(';').forEach(function(c){
    var t=c.trim();
    if (t.startsWith('sirdaba_app_token=')) appToken=t.substring('sirdaba_app_token='.length);
  });
  if (appToken) {
    window.SirDabaFlutter.postMessage(JSON.stringify({type:'app_token',token:decodeURIComponent(appToken)}));
  }

  if (typeof window._sirdabaLogoutPatched === 'undefined') {
    window._sirdabaLogoutPatched = true;
    function notifyLogout() {
      window.SirDabaFlutter.postMessage(JSON.stringify({type:'user_logged_out'}));
    }
    function isLogoutAction(str) {
      return str && (
        str.indexOf('sirdaba_client_logout') !== -1 ||
        str.indexOf('sirdaba_dist_logout') !== -1 ||
        str.indexOf('sirdaba_admin_logout') !== -1 ||
        str.indexOf('dist/logout') !== -1
      );
    }
    if (typeof jQuery !== 'undefined') {
      jQuery(document).ajaxComplete(function(event, xhr, settings) {
        try {
          if (isLogoutAction(settings.data||'') || isLogoutAction(settings.url||'')) {
            var d = JSON.parse(xhr.responseText);
            if (d && d.success) notifyLogout();
          }
        } catch(e) {}
      });
    }
    var OrigSend = XMLHttpRequest.prototype.send;
    var OrigOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(m, url) {
      this._sdUrl = url||'';
      return OrigOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function(body) {
      var bodyStr = (body||'').toString();
      if (isLogoutAction(bodyStr) || isLogoutAction(this._sdUrl)) {
        this.addEventListener('load', function() {
          try { var d=JSON.parse(this.responseText); if(d&&d.success) notifyLogout(); } catch(e) {}
        });
      }
      return OrigSend.apply(this, arguments);
    };
    var origFetch = window.fetch;
    window.fetch = function(input, init) {
      var url = (typeof input==='string') ? input : (input&&input.url)||'';
      var body = (init&&init.body) ? init.body.toString() : '';
      if (isLogoutAction(url) || isLogoutAction(body)) {
        return origFetch.apply(this, arguments).then(function(resp) {
          resp.clone().json().then(function(d){ if(d&&d.success) notifyLogout(); }).catch(function(){});
          return resp;
        });
      }
      return origFetch.apply(this, arguments);
    };
  }
})();
''');
  }

  void _onJsMessage(JavaScriptMessage msg) async {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      switch (type) {
        case 'user_logged_out':
          await _handleLogout();
          break;
        case 'app_token':
          final appToken = data['token'] as String? ?? '';
          if (appToken.isNotEmpty) {
            await _clearLogoutFlag();
            if (_fcmToken != null && !_tokenRegistered) {
              _registerFcmTokenWithAuth(_fcmToken!, appToken);
            }
          }
          break;
        case 'get_location':
          await _provideLocationToWebView();
          break;
        case 'open_datetime':
          await _openDateTimePicker(
            inputId: data['inputId'] as String? ?? '',
            inputName: data['inputName'] as String? ?? '',
            currentValue: data['currentValue'] as String? ?? '',
          );
          break;
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefIsLoggedOut, true);
    await prefs.remove('fcm_token_registered');
    _tokenRegistered = false;
    await WebViewCookieManager().clearCookies();
    if (mounted) {
      await _wvc.loadRequest(Uri.parse(kHomeUrl));
    }
  }

  Future<void> _clearLogoutFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefIsLoggedOut, false);
  }

  Future<void> _openDateTimePicker({
    required String inputId,
    required String inputName,
    required String currentValue,
  }) async {
    DateTime initialDate = DateTime.now();
    try {
      if (currentValue.isNotEmpty) initialDate = DateTime.parse(currentValue);
    } catch (_) {}
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFE8821A),
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFE8821A),
            onPrimary: Colors.white,
          ),
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    if (pickedTime == null || !mounted) return;
    final combined = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);
    final formatted =
        '${combined.year.toString().padLeft(4, '0')}-'
        '${combined.month.toString().padLeft(2, '0')}-'
        '${combined.day.toString().padLeft(2, '0')}T'
        '${combined.hour.toString().padLeft(2, '0')}:'
        '${combined.minute.toString().padLeft(2, '0')}';
    final escapedId = inputId.replaceAll("'", "\\'");
    final escapedName = inputName.replaceAll("'", "\\'");
    await _wvc.runJavaScript(
        "window._sirdabaSetDatetime('$escapedId','$escapedName','$formatted');");
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
(function(){
  if(typeof window._geoSuccessCallback==='function'){
    window._geoSuccessCallback({coords:{latitude:${pos.latitude},longitude:${pos.longitude},accuracy:${pos.accuracy},altitude:${pos.altitude},altitudeAccuracy:null,heading:null,speed:null},timestamp:${pos.timestamp.millisecondsSinceEpoch}});
  }
})();
''');
      } else {
        await _wvc.runJavaScript(
            "if(typeof window._geoErrorCallback==='function') window._geoErrorCallback({code:1,message:'Permission denied'});");
      }
    } catch (e) {
      debugPrint('Location error: $e');
      await _wvc.runJavaScript(
          "if(typeof window._geoErrorCallback==='function') window._geoErrorCallback({code:2,message:'Position unavailable'});");
    }
  }

  Future<void> _initFCM() async {
    final m = FirebaseMessaging.instance;
    await m.requestPermission(
        alert: true, badge: true, sound: true, provisional: false);
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
          n.hashCode, n.title, n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, channel.name,
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
        body: {'fcm_token': fcmToken, 'platform': 'android'},
      );
      if (response.statusCode == 200) {
        _tokenRegistered = true;
        await prefs.setString('fcm_token_registered', fcmToken);
        debugPrint('FCM token registered ✅');
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
