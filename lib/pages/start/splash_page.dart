import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/widgets/common/background.dart';
import 'package:gamezone/widgets/common/startup_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _loadingController;
  String _appVersion = '';
  static const String _kLogoPath = 'assets/images/logonobg.png';

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _setupLoadingAnimation();
    _loadAppVersion();
    // Navigasi halaman akan ditangani oleh LoadingBar.onComplete
  }

  @override
  void dispose() {
    _animationController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameZoneBackground(
        child: Stack(
          children: [
            // Menampilkan background splash aplikasi.
            Positioned.fill(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDarkNavy,
                      AppColors.primaryDarkNavy.withValues(alpha: 0.8),
                      AppColors.accentBlue.withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Menampilkan konten halaman splash.
            SafeArea(
              child: Stack(
                children: [
                  _buildGamingBackground(),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildLogo(),
                          ),
                        ),

                        const SizedBox(height: AppTheme.paddingXXL),

                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildTagline(),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: AppTheme.paddingXXXL,
                    left: 0,
                    right: 0,
                    child: _buildLoadingIndicator(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() => _appVersion = 'VERSION ${info.version}');
    } catch (_) {}
  }

  void _setupLoadingAnimation() {
    _loadingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _loadingController.forward();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  Widget _buildLogo() {
    return Column(
      children: [
        LogoBox(
          size: 140,
          child: Image.asset(
            _kLogoPath,
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXXL),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Game',
                  style: AppTextStyle.h2.copyWith(
                    color: AppColors.white,
                    fontSize: 40,
                  ),
                ),
                TextSpan(
                  text: 'Zone',
                  style: AppTextStyle.h2.copyWith(
                    color: AppColors.accentCyan,
                    fontSize: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingM),
          Text(
            'Pesan Tempat Mainmu.\nMain Tanpa Menunggu.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body2.copyWith(
              color: const Color(0xFFCBD5E1),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXXL),
          child: LoadingBar(
            duration: const Duration(seconds: 3),
            height: 8,
            onComplete: () {
              _handleStartupNavigation();
            },
          ),
        ),
        const SizedBox(height: AppTheme.paddingM),
        Text(
          _appVersion.isEmpty ? '' : _appVersion,
          style: AppTextStyle.caption2.copyWith(
            color: const Color(0xFF94A3B8),
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Future<void> _handleStartupNavigation() async {
    if (!mounted) return;

    // Gunakan resolveCurrentUser agar token Firebase Auth sempat dimuat
    // sebelum SplashPage memutuskan arah navigasi. Ini mencegah cold-start
    // race condition di mana currentUser masih null sesaat setelah app dibuka.
    final authService = AuthService();
    final user = await authService.resolveCurrentUser(
      timeout: const Duration(seconds: 3),
    );

    if (user == null) {
      // Tidak ada sesi aktif → tampilkan onboarding jika belum pernah dilihat,
      // atau langsung ke login jika sudah.
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seenOnboarding') ?? false;
      if (!mounted) return;
      if (seen) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
      return;
    }

    // Jika user sudah login, pastikan seenOnboarding bernilai true di preferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);
    } catch (_) {}

    try {
      final firestore = FirestoreService();
      final data = await firestore.getUserData(user.uid);

      if (data == null) {
        // Orphaned auth user - sign out dan arahkan ke login
        await authService.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final role = data['role'] as String? ?? 'user';
      final status = data['status'] as String? ?? 'active';

      if (role == 'admin' && status != 'active') {
        // Belum diverifikasi atau ditolak - paksa logout agar muncul pesan error di login
        await authService.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final String nextRoute;
      if (role == 'superadmin' || role == 'super_admin') {
        nextRoute = '/superadmin-dashboard';
      } else if (role == 'admin') {
        nextRoute = '/admin-dashboard';
      } else {
        nextRoute = '/user-dashboard';
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(nextRoute);
    } catch (e) {
      // Jika terjadi error saat memuat data profil tapi user sudah login,
      // arahkan ke /login (lakukan signOut demi keamanan) alih-alih menampilkan onboarding.
      try {
        await authService.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Widget _buildGamingBackground() {
    return Opacity(
      opacity: 0.15,
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentCyan.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentBlue.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
