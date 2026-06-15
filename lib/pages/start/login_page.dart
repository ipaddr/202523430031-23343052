import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../styles/gradients.dart';
import '../../widgets/common/background.dart';
import '../../widgets/common/auth_widgets.dart';

// Halaman masuk untuk semua jenis akun di aplikasi GameZone.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRedirecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Login utama membaca role user lalu mengarahkan ke dashboard yang sesuai.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Cek apakah user punya google.com tapi belum ada password provider (Kasus 3)
      List<String> methods = [];
      try {
        methods = await _authService.fetchSignInMethodsForEmail(email);
      } catch (e) {
        debugPrint('[Login] Gagal fetchSignInMethodsForEmail: $e');
      }

      if (methods.contains('google.com') && !methods.contains('password')) {
        // Kasus 3: Akun Google ada, tapi belum ada password provider.
        await _handleGoogleToEmailPasswordLink(email, password);
        return;
      }

      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }
      String role = 'user';
      final userId = credential.user?.uid;
      if (userId != null) {
        final data = await _firestoreService.getUserData(userId);
        if (!mounted) {
          return;
        }
        if (data != null) {
          if (data['role'] is String) {
            role = data['role'] as String;
          }
          final String status = data['status'] ?? 'active';
          if (role == 'admin' && status == 'pending') {
            await _authService.signOut();
            if (!mounted) return;
            setState(() {
              _errorMessage =
                  'Akun Admin Anda masih dalam proses verifikasi oleh Super Admin. Harap tunggu.';
              _isLoading = false;
            });
            return;
          } else if (role == 'admin' && status == 'rejected') {
            await _authService.signOut();
            if (!mounted) return;
            setState(() {
              _errorMessage =
                  'Pendaftaran Admin Anda ditolak oleh Super Admin.';
              _isLoading = false;
            });
            return;
          }
        }
      }
      if (!mounted) {
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
      Navigator.of(context).pushReplacementNamed(nextRoute);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapFirebaseError(error.code);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('[Login] Error masuk (non-Firebase): $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan. Coba lagi nanti.';
      });
    } finally {
      if (mounted && !_isRedirecting) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleToEmailPasswordLink(
    String email,
    String password,
  ) async {
    bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF11182D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
            ),
          ),
          title: const Text(
            'Hubungkan Sandi ke Google',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Akun $email terdaftar menggunakan Google.\n\n'
            'Silakan masuk menggunakan Google terlebih dahulu untuk menghubungkan kata sandi ini ke akun Anda.',
            style: const TextStyle(
              color: Color(0xFFD5DBF2),
              height: 1.4,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text(
                'Lanjutkan Google Sign In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (proceed != true || !mounted) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (googleUser.email.toLowerCase() != email.toLowerCase()) {
        setState(() {
          _errorMessage =
              'Email Google harus sama dengan email yang dimasukkan.';
          _isLoading = false;
        });
        return;
      }

      final OAuthCredential googleCredential = await _authService
          .buildGoogleCredential(googleUser);
      final userCred = await _authService.signInWithCredential(
        googleCredential,
      );
      final user = userCred.user;

      if (user != null) {
        if (kDebugMode) {
          debugPrint(
            "[Login] Data provider sebelum linking: ${user.providerData.map((p) => p.providerId).toList()}",
          );
        }
        await _authService.linkPasswordToCurrentUser(
          email: email,
          password: password,
        );
        if (kDebugMode) {
          debugPrint(
            "[Login] Data provider setelah linking: ${user.providerData.map((p) => p.providerId).toList()}",
          );
          debugPrint('[Login] Password provider berhasil dihubungkan ke akun Google');
        }

        final providers = user.providerData.map((p) => p.providerId).toList();
        if (kDebugMode) {
          debugPrint(
            "[Login] Provider aktif (setelah linking): ${providers.join(', ')}",
          );
        }

        var userData = await _firestoreService.getUserData(user.uid);
        if (userData == null) {
          userData = {
            'nama': user.displayName ?? googleUser.displayName ?? '',
            'email': email,
            'noHp': '',
            'foto': '',
            'role': 'user',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          };
          await _firestoreService.createUser(user.uid, userData);
        }
        await _navigateToDashboard(user, userData);
      }
    } catch (e) {
      debugPrint('[Login] Gagal linking Google ke Email/Password: $e');
      setState(() {
        _errorMessage = 'Gagal menghubungkan kata sandi: $e';
        _isLoading = false;
      });
    }
  }

  String _mapFirebaseError(String code) {
    // Ubah kode error Firebase menjadi pesan yang lebih mudah dibaca.
    // Firebase SDK versi baru menggabungkan 'user-not-found' & 'wrong-password'
    // menjadi 'invalid-credential' untuk alasan keamanan.
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'invalid-credential':
        // Firebase SDK >=v10: menggantikan 'user-not-found' dan 'wrong-password'
        return 'Email atau password salah. Periksa kembali dan coba lagi.';
      case 'user-not-found':
        return 'Email belum terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Gagal terhubung ke jaringan. Periksa koneksi internet Anda.';
      case 'operation-not-allowed':
        return 'Login dengan email & password tidak diizinkan. Hubungi administrator.';
      default:
        return 'Login gagal ($code). Periksa kembali email dan password.';
    }
  }

  Future<void> _forgotPassword() async {
    // Reset password dikirim ke email yang sedang diisi.
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan email terlebih dahulu.';
      });
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link reset password sudah dikirim ke email.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapFirebaseError(error.code))));
    }
  }



  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String googleEmail = googleUser.email;
      final OAuthCredential googleCredential = await _authService
          .buildGoogleCredential(googleUser);

      if (kDebugMode) {
        debugPrint('[Login] Memulai masuk Google: $googleEmail');
      }

      // Cek apakah email sudah punya password provider tapi Google belum terhubung
      List<String> methods = [];
      try {
        methods = await _authService.fetchSignInMethodsForEmail(googleEmail);
      } catch (e) {
        debugPrint('[Login] Gagal fetching methods: $e');
      }

      final bool hasExistingPassword = methods.contains('password');
      final bool hasGoogle = methods.contains('google.com');

      if (hasExistingPassword && !hasGoogle) {
        if (kDebugMode) {
          debugPrint(
            '[Login] Akun email/password ada tapi Google belum terhubung. Melakukan linking...',
          );
        }
        await _performEmailPasswordLinkFlow(
          googleEmail,
          googleCredential,
          googleSignIn,
        );
        return;
      }

      // Langkah 1: Coba sign in Google langsung
      UserCredential googleSignInResult;
      try {
        googleSignInResult = await _authService.signInWithCredential(
          googleCredential,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // KASUS C: Firebase mencegah pembuatan akun duplikat.
          if (kDebugMode) {
            debugPrint('[Login] Akun sudah ada, perlu linking');
          }
          await _performEmailPasswordLinkFlow(
            googleEmail,
            googleCredential,
            googleSignIn,
          );
          return;
        }
        rethrow;
      }

      final User? newUser = googleSignInResult.user;
      if (newUser == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Gagal mendapatkan data pengguna.',
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[Login] Google sign in result - isNewUser: ${googleSignInResult.additionalUserInfo?.isNewUser}, uid: ${newUser.uid}',
        );
      }

      // Periksa metode sign-in email ini untuk membedakan Kasus 1 vs Kasus 2
      final bool isNewUser =
          googleSignInResult.additionalUserInfo?.isNewUser ?? false;

      // Langkah 2: Deteksi apakah Firebase baru buat akun dan password exists (KASUS B/Kasus 2)
      if (isNewUser && hasExistingPassword) {
        if (kDebugMode) {
          debugPrint(
            '[Login] isNewUser=true dan ada password account. Hapus akun Google baru, perlu linking.',
          );
        }
        try {
          await newUser.delete();
        } catch (deleteErr) {
          debugPrint('[Login] Gagal menghapus akun Google baru: $deleteErr');
        }
        await _authService.signOut();

        // Jalankan flow linking email+password → Google
        await _performEmailPasswordLinkFlow(
          googleEmail,
          googleCredential,
          googleSignIn,
        );
        return;
      }

      var userData = await _firestoreService.getUserData(newUser.uid);
      if (userData == null) {
        if (isNewUser) {
          try {
            await newUser.delete();
          } catch (deleteErr) {
            debugPrint('[Login] Gagal menghapus akun Google baru: $deleteErr');
          }
        }
        await _authService.signOut();
        setState(() {
          _errorMessage =
              'Akun Gmail ini belum terdaftar. Silakan registrasi terlebih dahulu.';
          _isLoading = false;
        });
        return;
      }

      final providers = newUser.providerData.map((p) => p.providerId).toList();
      if (kDebugMode) {
        debugPrint(
          "[Login] Provider aktif (Google Login berhasil): ${providers.join(', ')}",
        );
        debugPrint('[Login] Data Firestore OK - role: ${userData['role']}');
      }
      await _navigateToDashboard(newUser, userData);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _mapFirebaseError(error.code));
    } catch (e) {
      if (!mounted) return;
      debugPrint('[Login] Error login Google: $e');
      setState(() => _errorMessage = 'Gagal login dengan Google. Coba lagi.');
    } finally {
      if (mounted && !_isRedirecting) setState(() => _isLoading = false);
    }
  }

  /// Flow linking: sign in email+password → link Google credential.
  /// Dipanggil saat perlu menghubungkan Google ke akun email+password yang ada.
  Future<void> _performEmailPasswordLinkFlow(
    String email,
    OAuthCredential googleCredential,
    GoogleSignIn googleSignIn,
  ) async {
    if (!mounted) return;

    setState(() => _isLoading = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _PasswordLinkingDialog(
          email: email,
          googleCredential: googleCredential,
          googleSignIn: googleSignIn,
          authService: _authService,
          firestoreService: _firestoreService,
          onSuccess: (user, userData) {
            if (!mounted) return;
            _navigateToDashboard(user, userData);
          },
          onError: (message) {
            if (!mounted) return;
            setState(() {
              _errorMessage = message;
              _isLoading = false;
            });
          },
        );
      },
    );
  }

  /// Validasi status akun lalu navigasi ke dashboard sesuai role.
  /// TIDAK menyinkronisasi foto dari Google — foto hanya diisi user sendiri.
  Future<void> _navigateToDashboard(
    User user,
    Map<String, dynamic> userData,
  ) async {
    if (!mounted) return;

    final String role = userData['role'] as String? ?? 'user';
    final String status = userData['status'] as String? ?? 'active';

    if (role == 'admin' && status == 'pending') {
      await _authService.signOut();
      setState(() {
        _errorMessage =
            'Akun Admin Anda masih dalam proses verifikasi oleh Super Admin. Harap tunggu.';
        _isLoading = false;
      });
      return;
    }
    if (role == 'admin' && status == 'rejected') {
      await _authService.signOut();
      setState(() {
        _errorMessage = 'Pendaftaran Admin Anda ditolak oleh Super Admin.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    _isRedirecting = true;
    final String nextRoute;
    if (role == 'superadmin' || role == 'super_admin') {
      nextRoute = '/superadmin-dashboard';
    } else if (role == 'admin') {
      nextRoute = '/admin-dashboard';
    } else {
      nextRoute = '/user-dashboard';
    }
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  void _showRegisterInfo() {
    Navigator.of(context).pushNamed('/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  gradient: Gradients.kAccent,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x553B82F6),
                                      blurRadius: 22,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Image.asset(
                                    'assets/images/logonobg.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: AppTextStyle.h2.copyWith(
                                  fontSize: 30,
                                  color: AppColors.white,
                                ),
                                children: const [
                                  TextSpan(text: 'Game'),
                                  TextSpan(
                                    text: 'Zone',
                                    style: TextStyle(color: Color(0xFF22D3EE)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Selamat datang kembali, Gamers!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9AA3C3),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 22),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _errorMessage == null
                                  ? const SizedBox.shrink()
                                  : AuthErrorBanner(
                                      key: const ValueKey('error'),
                                      message: _errorMessage!,
                                    ),
                            ),
                            const AuthFieldLabel(text: 'EMAIL'),
                            const SizedBox(height: 8),
                            AuthGameZoneField(
                              controller: _emailController,
                              hintText: 'contoh@email.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: Icons.mail_outline_rounded,
                              validator: (value) {
                                final input = value?.trim() ?? '';
                                if (input.isEmpty) return 'Email wajib diisi.';
                                if (!input.contains('@')) {
                                  return 'Format email tidak valid.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const AuthFieldLabel(text: 'KATA SANDI'),
                                TextButton(
                                  onPressed: _forgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'LUPA?',
                                    style: TextStyle(
                                      color: Color(0xFF22D3EE),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AuthGameZoneField(
                              controller: _passwordController,
                              hintText: '••••••••',
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              onFieldSubmitted: (_) => _login(),
                              validator: (value) {
                                final input = value?.trim() ?? '';
                                if (input.isEmpty) {
                                  return 'Password wajib diisi.';
                                }
                                if (input.length < 6) {
                                  return 'Password minimal 6 karakter.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),
                            AuthPrimaryButton(
                              isLoading: _isLoading,
                              onPressed: _login,
                              text: 'Masuk',
                            ),
                            const SizedBox(height: 22),
                            const AuthSectionDivider(text: 'atau masuk dengan'),
                            const SizedBox(height: 20),
                            AuthSocialButton(
                              onPressed: _isLoading ? () {} : _loginWithGoogle,
                            ),
                            const SizedBox(height: 20),
                            AuthFooterPrompt(onTap: _showRegisterInfo),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PasswordLinkingDialog extends StatefulWidget {
  final String email;
  final OAuthCredential googleCredential;
  final GoogleSignIn googleSignIn;
  final AuthService authService;
  final FirestoreService firestoreService;
  final Function(User user, Map<String, dynamic> userData) onSuccess;
  final Function(String message) onError;

  const _PasswordLinkingDialog({
    required this.email,
    required this.googleCredential,
    required this.googleSignIn,
    required this.authService,
    required this.firestoreService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_PasswordLinkingDialog> createState() => _PasswordLinkingDialogState();
}

class _PasswordLinkingDialogState extends State<_PasswordLinkingDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _isDialogLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isDialogLoading = true;
    });

    try {
      // 1. Verifikasi password menggunakan Firebase Auth
      await widget.authService.signInWithEmailAndPassword(
        email: widget.email,
        password: password,
      );

      // 2. Jika password benar, lakukan linkWithCredential
      await widget.authService.linkGoogleToCurrentUser(widget.googleCredential);

      // Muat ulang pengguna untuk sinkronisasi provider
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
      }

      if (!mounted) return;
      // Tutup dialog kata sandi
      Navigator.of(context).pop();

      // Ambil data pengguna dan jalankan onSuccess
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var userData = await widget.firestoreService.getUserData(user.uid);
        if (userData == null) {
          userData = {
            'nama': user.displayName ?? '',
            'email': widget.email,
            'noHp': '',
            'foto': '',
            'role': 'user',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          };
          await widget.firestoreService.createUser(user.uid, userData);
        }
        widget.onSuccess(user, userData);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDialogLoading = false;
      });

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        // Tampilkan dialog error
        showDialog<void>(
          context: context,
          builder: (errCtx) => AlertDialog(
            backgroundColor: const Color(0xFF11182D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
              ),
            ),
            title: const Text(
              'Error',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Password yang Anda masukkan salah.',
              style: TextStyle(color: Color(0xFFD5DBF2)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(errCtx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        return;
      }
      widget.onError(e.message ?? 'Gagal menghubungkan kata sandi.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDialogLoading = false;
      });
      widget.onError('Terjadi kesalahan: $e');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF11182D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
        ),
      ),
      title: const Text(
        'Hubungkan Akun Google',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Akun ini sudah terdaftar menggunakan Email & Password.\nMasukkan password untuk menghubungkan akun Google.',
            style: const TextStyle(
              color: Color(0xFFD5DBF2),
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDialogLoading
              ? null
              : () {
                  widget.googleSignIn.signOut();
                  Navigator.of(context).pop();
                },
          child: const Text(
            'Batal',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22D3EE),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isDialogLoading ? null : _submit,
          child: _isDialogLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Hubungkan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
