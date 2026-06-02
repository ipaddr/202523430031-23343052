import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gamezone/firebase_options.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/pages/start/splash_page.dart';
import 'package:gamezone/pages/start/onboarding_page.dart';
import 'package:gamezone/pages/start/register_page.dart';
import 'package:gamezone/pages/start/login_page.dart';
import 'package:gamezone/pages/user/user_dashboard.dart';
import 'package:gamezone/pages/admin/admin_dashboard.dart';
import 'package:gamezone/pages/admin/room_form_page.dart';
import 'package:gamezone/pages/admin/room_page.dart';
import 'package:gamezone/pages/admin/booking_detail_page.dart';
import 'package:gamezone/pages/superadmin/superadmin_dashboard.dart';
import 'package:gamezone/pages/edit_profile_page.dart';
import 'package:gamezone/pages/shared/station_detail_page.dart';
import 'package:gamezone/pages/shared/room_detail_page.dart'
    show SharedRoomDetailPage;
import 'package:gamezone/pages/user/booking_form_page.dart';
import 'package:gamezone/pages/user/payment_page.dart';
import 'package:firebase_core/firebase_core.dart';

// Konfigurasi system UI global.
const SystemUiOverlayStyle _gameZoneSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

// Titik masuk aplikasi dan peta route utama GameZone.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Konfigurasi edge-to-edge Android.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Konfigurasi system navigation bar.
  SystemChrome.setSystemUIOverlayStyle(_gameZoneSystemUiStyle);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp memegang tema, halaman awal, dan semua route.
    return MaterialApp(
      title: 'GameZone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) {
        // Menjaga style system bar tetap konsisten di seluruh route.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _gameZoneSystemUiStyle,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Menutup keyboard ketika area luar form ditekan
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashPage(),
      routes: {
        '/splash': (context) => const SplashPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/user-dashboard': (context) => const UserDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboardPage(),
        '/admin-room': (context) => const RoomPage(),
        '/admin-room-detail': (context) => const SharedRoomDetailPage(),
        '/admin-room-form': (context) => const RoomFormPage(),
        '/admin-booking-detail': (context) => const BookingDetailPage(),
        '/superadmin-dashboard': (context) => const SuperAdminDashboardPage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/station-detail': (context) => const StationDetailPage(),
        '/room-detail': (context) => const SharedRoomDetailPage(),
        '/booking-form': (context) => const BookingFormPage(),
        '/payment': (context) => const PaymentPage(),
      },
    );
  }
}
