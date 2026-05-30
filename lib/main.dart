import 'package:flutter/material.dart';
import 'package:gamezone/firebase_options.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/pages/start/splash_page.dart';
import 'package:gamezone/pages/start/onboarding_page.dart';
import 'package:gamezone/pages/start/register_page.dart';
import 'package:gamezone/pages/start/login_page.dart';
import 'package:gamezone/pages/user/user_dashboard.dart';
import 'package:gamezone/pages/admin/admin_dashboard.dart';
import 'package:gamezone/pages/superadmin/superadmin_dashboard.dart';
import 'package:gamezone/pages/edit_profile_page.dart';
import 'package:firebase_core/firebase_core.dart';

// Titik masuk aplikasi dan peta route utama GameZone.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const SplashPage(),
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/user-dashboard': (context) => const UserDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboardPage(),
        '/superadmin-dashboard': (context) => const SuperAdminDashboardPage(),
        '/edit-profile': (context) => const EditProfilePage(),
      },
    );
  }
}
