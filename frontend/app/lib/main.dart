import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/driver_registration_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/phone_input_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/booking/screens/destination_screen.dart';
import 'features/booking/screens/trip_screen.dart';
import 'features/booking/screens/waiting_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/splash_screen.dart';
import 'features/passenger/screens/edit_profile_screen.dart';
import 'features/passenger/screens/help_screen.dart';
import 'features/passenger/screens/notification_screen.dart';
import 'features/passenger/screens/promo_screen.dart';
import 'features/passenger/screens/saved_address_screen.dart';
import 'features/driver/screens/driver_notification_screen.dart';
import 'features/driver/screens/driver_subscription_screen.dart';
import 'features/admin/screens/admin_driver_detail_screen.dart';
import 'features/admin/screens/admin_passenger_detail_screen.dart';
import 'features/admin/screens/admin_notification_screen.dart';
import 'features/admin/screens/admin_pending_drivers_screen.dart';
import 'features/admin/screens/admin_reports_screen.dart';
import 'features/admin/screens/admin_complaints_screen.dart';
import 'features/passenger/screens/passenger_complaint_screen.dart';
import 'features/passenger/screens/upgrade_to_driver_screen.dart';
import 'features/chat/screens/chat_history_screen.dart';
import 'features/shared/screens/main_screen.dart';
import 'features/order/screens/order_notification_screen.dart';
import 'core/widgets/location_gate.dart';

final navigatorKey = GlobalKey<NavigatorState>();

bool _isDeviceCompromised = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _isDeviceCompromised = false;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);
  FcmService.init(navigatorKey);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(ProviderScope(child: LungoApp(compromised: _isDeviceCompromised)));
}

class LungoApp extends StatelessWidget {
  final bool compromised;
  const LungoApp({super.key, this.compromised = false});

  @override
  Widget build(BuildContext context) {
    if (compromised) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFFEF4444), size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Perangkat Tidak Aman',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lungo tidak dapat berjalan di perangkat yang telah di-root atau di-jailbreak demi keamanan data Anda.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Lungo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      color: AppColors.backgroundColor,
      theme: AppTheme.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const PhoneInputScreen(),
        '/otp': (_) => const OtpScreen(),
        '/register': (_) => const RegisterScreen(),
        '/driver-register': (_) => const DriverRegistrationScreen(),
        '/home': (_) => const HomeScreen(),
        '/main': (_) => const LocationGate(child: MainScreen()),
        '/destination': (_) => const DestinationScreen(),
        '/waiting': (_) => const WaitingScreen(),
        '/trip': (_) => const TripScreen(),
        '/profile/edit': (_) => const EditProfileScreen(),
        '/profile/addresses': (_) => const SavedAddressScreen(),
        '/profile/notifications': (_) => const NotificationScreen(),
        '/profile/promo': (_) => const PromoScreen(),
        '/profile/help': (_) => const HelpScreen(),
        '/driver/notifications': (_) => const DriverNotificationScreen(),
        '/driver/subscription': (_) => const DriverSubscriptionScreen(),
        '/admin/notifications': (_) => const AdminNotificationScreen(),
        '/admin/pending-drivers': (_) => const AdminPendingDriversScreen(),
        '/admin/reports': (_) => const AdminReportsScreen(),
        '/admin/complaints': (_) => const AdminComplaintsScreen(),
        '/profile/complaint': (_) => const PassengerComplaintScreen(),
        '/upgrade-to-driver': (_) => const UpgradeToDriverScreen(),
        '/order': (_) => const OrderNotificationScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/admin/driver-detail') {
          final driverId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => AdminDriverDetailScreen(driverId: driverId),
          );
        }
        if (settings.name == '/admin/passenger-detail') {
          final userId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => AdminPassengerDetailScreen(userId: userId),
          );
        }
        if (settings.name == '/chat-history') {
          final args = settings.arguments as ChatHistoryArgs;
          return MaterialPageRoute(
            builder: (_) => ChatHistoryScreen(args: args),
          );
        }
        return null;
      },
    );
  }
}
