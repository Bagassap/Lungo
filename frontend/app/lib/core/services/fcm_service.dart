import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../network/dio_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  assert(() { debugPrint('[FCM] Background: ${message.notification?.title}'); return true; }());
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;

  // Pending tab index consumed by MainScreen on next navigation to /main
  static int _pendingTabIndex = -1;
  static int consumePendingTabIndex() {
    final idx = _pendingTabIndex;
    _pendingTabIndex = -1;
    return idx;
  }

  // Pending ride navigation: {route, rideId} — consumed by MainScreen
  static Map<String, String>? _pendingRideNav;
  static Map<String, String>? consumePendingRideNav() {
    final nav = _pendingRideNav;
    _pendingRideNav = null;
    return nav;
  }

  // Pending driver accept from notification — consumed by DriverHomeScreen
  static Map<String, dynamic>? _pendingDriverAccept;
  static void setPendingDriverAccept(Map<String, dynamic> data) {
    _pendingDriverAccept = data;
  }
  static Map<String, dynamic>? consumePendingDriverAccept() {
    final d = _pendingDriverAccept;
    _pendingDriverAccept = null;
    return d;
  }

  // Guard: true saat card order sedang tampil di DriverHomeScreen
  // Cegah FCM banner tap mem-navigate ulang saat card sudah aktif
  static bool _hasActivePendingRequest = false;
  static void setHasActivePendingRequest(bool value) {
    _hasActivePendingRequest = value;
  }

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] onMessage raw data: ${message.data}');
      final title = message.notification?.title ?? '';
      final body  = message.notification?.body  ?? '';
      _showInAppBanner(title, body, message.data);
    });

    // App in background → user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] onMessageOpenedApp raw data: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // App terminated → user tapped notification
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationTap(initial.data);
      });
    }

    await _registerToken();

    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveToken(newToken);
    });
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    switch (type) {
      case 'NEW_RIDE_REQUEST':
        debugPrint('[FCM] NEW_RIDE_REQUEST raw: $data');
        debugPrint('[FCM] passengerName: ${data['passengerName']}');
        debugPrint('[FCM] destLat: ${data['destinationLat']}');
        // Jika card order sudah tampil (dari socket), abaikan FCM tap
        // agar tidak navigate ulang dan skip card accept/reject driver
        if (_hasActivePendingRequest) {
          debugPrint('[FCM] NEW_RIDE_REQUEST diabaikan — card order sedang aktif');
          return;
        }
        FcmService.setPendingDriverAccept(Map<String, dynamic>.from(data));
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'DRIVER_ACCEPTED':
      case 'DRIVER_PICKUP':
        final rideIdWait = data['rideId'] as String? ?? '';
        _pendingRideNav = {'route': '/waiting', 'rideId': rideIdWait};
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'RIDE_STARTED':
        final rideIdTrip = data['rideId'] as String? ?? '';
        // Route ke /waiting — _fetchAndRestorePhase detects ONGOING dan push /trip
        // dengan TripArgs lengkap dari API. Direct push /trip tanpa TripArgs
        // menyebabkan template kosong (default LatLng).
        _pendingRideNav = {'route': '/waiting', 'rideId': rideIdTrip};
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'CHAT_FROM_DRIVER':
      case 'CHAT_FROM_PASSENGER':
        // Tab 2 = Chat (baik untuk passenger maupun driver)
        _pendingTabIndex = 2;
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'RIDE_DONE':
        // Passenger: tab 1 = Aktivitas (riwayat perjalanan + prompt rating)
        _pendingTabIndex = 1;
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'DRIVER_TRIP_DONE':
        // Driver: tab 1 = Aktivitas driver (riwayat & pendapatan)
        _pendingTabIndex = 1;
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'RIDE_CANCELLED':
        // Keduanya: kembali ke Home (tab 0) agar bisa cari lagi
        _pendingTabIndex = 0;
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
      case 'ADMIN_BROADCAST':
        // Tab 3 = Profile — berisi link ke halaman notifikasi
        _pendingTabIndex = 3;
        nav.pushNamedAndRemoveUntil('/main', (_) => false);
    }
  }

  static void _showInAppBanner(String title, String body, [Map<String, dynamic>? data]) {
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              if (entry.mounted) entry.remove();
              if (data != null) _handleNotificationTap(data);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bike, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          ).createShader(bounds),
                          child: Text(title, style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                        ),
                        const SizedBox(height: 2),
                        Text(body, style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (_) {}
  }

  static Future<void> registerTokenAfterLogin() => _registerToken();

  static Future<void> _saveToken(String token) async {
    try {
      await DioClient.create().post('/users/fcm-token', data: {'fcmToken': token});
      debugPrint('[FCM] FCM token disimpan ke backend');
    } catch (_) {}
  }
}

