import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class SirDabaApp extends StatelessWidget {
  const SirDabaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SirDaba',
      debugShowCheckedModeBanner: false,
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
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 SirDabaApp/1.0 SirDaba-App-Android-Agent')
      ..addJavaScriptChannel('SirDabaFlutter',
          onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
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
      ..setOnConsoleMessage((msg) {
        debugPrint('WebView console: ${msg.message}');
      })
      ..loadRequest(Uri.parse('$kSiteUrl/'));

    final platform = _wvc.platform;
    if (platform is AndroidWebViewController) {
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
    setState(() => _loading = false);
    _wvc.runJavaScript('''
      (function() {

        // ✅ FIX 1: window.open + target=_blank
        if (typeof window._sirdabaOpenPatched === 'undefined') {
          window._sirdabaOpenPatched = true;
          var _origOpen = window.open;
          window.open = function(url, target, features) {
            if (url && url !== '' && url !== 'about:blank') {
              window.location.href = url;
              return window;
            }
            return _origOpen ? _origOpen.call(window, url, target, features) : null;
          };
          document.addEventListener('click', function(e) {
            var el = e.target;
            while (el && el.tagName !== 'A') el = el.parentElement;
            if (el && el.tagName === 'A' && el.target === '_blank' && el.href) {
              e.preventDefault();
              window.location.href = el.href;
            }
          }, true);
        }

        // ✅ FIX 2: Date/Time Picker
        if (typeof window._sirdabaPickerPatched === 'undefined') {
          window._sirdabaPickerPatched = true;
          var styleEl = document.createElement('style');
          styleEl.textContent = '#sd-picker-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.5);z-index:999999;display:flex;align-items:flex-end;justify-content:center}#sd-picker-box{background:#fff;border-radius:16px 16px 0 0;padding:16px;width:100%;max-width:480px;font-family:sans-serif}#sd-picker-box h3{margin:0 0 12px;font-size:16px;text-align:center;color:#333}#sd-picker-selects{display:flex;gap:8px;justify-content:center;margin-bottom:16px}#sd-picker-selects select{flex:1;padding:10px 4px;border:1px solid #ddd;border-radius:8px;font-size:15px;text-align:center;background:#f9f9f9}#sd-picker-btns{display:flex;gap:8px}#sd-picker-btns button{flex:1;padding:12px;border:none;border-radius:8px;font-size:15px;cursor:pointer}#sd-btn-cancel{background:#f0f0f0;color:#555}#sd-btn-ok{background:#E8821A;color:#fff;font-weight:bold}';
          document.head.appendChild(styleEl);
          function pad(n){return String(n).padStart(2,'0');}
          function showDatePicker(input){
            var now=input.value?new Date(input.value):new Date();
            var y=now.getFullYear(),m=now.getMonth()+1,d=now.getDate();
            var yOpts='',mOpts='',dOpts='';
            for(var i=2020;i<=2030;i++)yOpts+='<option value="'+i+'"'+(i===y?' selected':'')+'>'+i+'</option>';
            var mNames=['يناير','فبراير','مارس','أبريل','ماي','يونيو','يوليوز','غشت','شتنبر','أكتوبر','نونبر','دجنبر'];
            for(var i=1;i<=12;i++)mOpts+='<option value="'+i+'"'+(i===m?' selected':'')+'>'+pad(i)+' - '+mNames[i-1]+'</option>';
            for(var i=1;i<=31;i++)dOpts+='<option value="'+i+'"'+(i===d?' selected':'')+'>'+pad(i)+'</option>';
            var overlay=document.createElement('div');
            overlay.id='sd-picker-overlay';
            overlay.innerHTML='<div id="sd-picker-box"><h3>اختر التاريخ</h3><div id="sd-picker-selects"><select id="sd-sel-y">'+yOpts+'</select><select id="sd-sel-m">'+mOpts+'</select><select id="sd-sel-d">'+dOpts+'</select></div><div id="sd-picker-btns"><button id="sd-btn-cancel">إلغاء</button><button id="sd-btn-ok">تأكيد</button></div></div>';
            document.body.appendChild(overlay);
            document.getElementById('sd-btn-cancel').onclick=function(){document.body.removeChild(overlay);};
            document.getElementById('sd-btn-ok').onclick=function(){
              var yv=document.getElementById('sd-sel-y').value;
              var mv=pad(document.getElementById('sd-sel-m').value);
              var dv=pad(document.getElementById('sd-sel-d').value);
              input.value=yv+'-'+mv+'-'+dv;
              input.dispatchEvent(new Event('change',{bubbles:true}));
              input.dispatchEvent(new Event('input',{bubbles:true}));
              document.body.removeChild(overlay);
            };
          }
          function showTimePicker(input){
            var parts=input.value?input.value.split(':'):['12','00'];
            var hh=parseInt(parts[0])||12,mm=parseInt(parts[1])||0;
            var hOpts='',mOpts='';
            for(var i=0;i<=23;i++)hOpts+='<option value="'+i+'"'+(i===hh?' selected':'')+'>'+pad(i)+'</option>';
            for(var i=0;i<=59;i++)mOpts+='<option value="'+i+'"'+(i===mm?' selected':'')+'>'+pad(i)+'</option>';
            var overlay=document.createElement('div');
            overlay.id='sd-picker-overlay';
            overlay.innerHTML='<div id="sd-picker-box"><h3>اختر الوقت</h3><div id="sd-picker-selects"><select id="sd-sel-h">'+hOpts+'</select><select id="sd-sel-m">'+mOpts+'</select></div><div id="sd-picker-btns"><button id="sd-btn-cancel">إلغاء</button><button id="sd-btn-ok">تأكيد</button></div></div>';
            document.body.appendChild(overlay);
            document.getElementById('sd-btn-cancel').onclick=function(){document.body.removeChild(overlay);};
            document.getElementById('sd-btn-ok').onclick=function(){
              var hv=pad(document.getElementById('sd-sel-h').value);
              var mv=pad(document.getElementById('sd-sel-m').value);
              input.value=hv+':'+mv;
              input.dispatchEvent(new Event('change',{bubbles:true}));
              input.dispatchEvent(new Event('input',{bubbles:true}));
              document.body.removeChild(overlay);
            };
          }
          function patchInputs(){
            document.querySelectorAll('input[type=date]').forEach(function(el){
              if(el._sdPatched)return;el._sdPatched=true;
              el.setAttribute('readonly','true');
              el.addEventListener('click',function(e){e.preventDefault();showDatePicker(el);});
              el.addEventListener('focus',function(e){e.preventDefault();el.blur();showDatePicker(el);});
            });
            document.querySelectorAll('input[type=time]').forEach(function(el){
              if(el._sdPatched)return;el._sdPatched=true;
              el.setAttribute('readonly','true');
              el.addEventListener('click',function(e){e.preventDefault();showTimePicker(el);});
              el.addEventListener('focus',function(e){e.preventDefault();el.blur();showTimePicker(el);});
            });
            document.querySelectorAll('input[type=datetime-local]').forEach(function(el){
              if(el._sdPatched)return;el._sdPatched=true;
              el.setAttribute('readonly','true');
              el.addEventListener('click',function(e){e.preventDefault();showDatePicker(el);});
              el.addEventListener('focus',function(e){e.preventDefault();el.blur();showDatePicker(el);});
            });
          }
          patchInputs();
          new MutationObserver(function(){patchInputs();}).observe(document.body,{childList:true,subtree:true});
        }

        // ✅ FIX 3: Geolocation
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

        // ✅ FIX 4: App token
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
      }
    } catch (_) {}
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
