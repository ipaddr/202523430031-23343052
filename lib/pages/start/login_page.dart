import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../styles/gradients.dart';
import '../../widgets/background.dart';
import '../../widgets/auth_widgets.dart';

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
      final credential = await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      String role = 'user';
      final userId = credential.user?.uid;
      if (userId != null) {
        final data = await _firestoreService.getUserData(userId);
        if (data != null) {
          if (data['role'] is String) {
            role = data['role'] as String;
          }
          final String status = data['status'] ?? 'active';
          if (role == 'admin' && status == 'pending') {
            await _authService.signOut();
            setState(() {
              _errorMessage =
                  'Akun Admin Anda masih dalam proses verifikasi oleh Super Admin. Harap tunggu.';
              _isLoading = false;
            });
            return;
          } else if (role == 'admin' && status == 'rejected') {
            await _authService.signOut();
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
      debugPrint('Login error (non-Firebase): $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan. Coba lagi nanti.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  /// Menampilkan dialog minta password agar Google credential bisa di-link
  /// ke akun email+password yang sudah ada.
  /// Mengembalikan password yang diinput, atau null jika dibatalkan.
  Future<String?> _askPasswordForLinking(String email) async {
    final controller = TextEditingController();
    bool obscure = true;
    String? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                    'Akun $email sudah terdaftar dengan Email & Password.\n\n'
                    'Masukkan password Anda untuk menghubungkan akun Google ke akun ini.',
                    style: const TextStyle(
                      color: Color(0xFFD5DBF2),
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
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
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
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
                  onPressed: () {
                    result = controller.text;
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text(
                    'Hubungkan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return (result != null && result!.isNotEmpty) ? result : null;
  }

  Future<void> _loginWithGoogle() async {
    // ─── FLOW LOGIN GOOGLE — 1 EMAIL = 1 AKUN ──────────────────────────────
    //
    // Prinsip: JANGAN bergantung pada fetchSignInMethodsForEmail (deprecated,
    // sering return [] sehingga tidak reliable sebagai guard).
    //
    // Algoritma yang benar:
    //
    //   1. Sign in Google → dapat googleUser (belum sentuh Firebase Auth)
    //   2. Bangun googleCredential
    //   3. Coba signInWithCredential(googleCredential)
    //
    //      KASUS A — berhasil, isNewUser == false:
    //        Akun Firebase sudah ada DAN sudah punya Google provider.
    //        → cek Firestore → masuk dashboard ✅
    //
    //      KASUS B — berhasil, isNewUser == true:
    //        Firebase baru buat akun baru via Google credential.
    //        Ini artinya email ini belum punya Google provider di Firebase Auth
    //        sebelumnya → akun ini "mengambil alih" email dari akun email+password.
    //        SEGERA hapus akun baru ini, minta password user, sign in
    //        email+password, lalu link Google ke akun lama.
    //        → setelah linking, DUA provider aktif di satu akun ✅
    //
    //      KASUS C — throw account-exists-with-different-credential:
    //        Firebase "One account per email" aktif.
    //        Sama dengan KASUS B tapi Firebase menolak duluan.
    //        → minta password → sign in email+password → link Google ✅
    //
    // Dengan ini, flow benar 100% terlepas dari setting Firebase Console.
    // ──────────────────────────────────────────────────────────────────────

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

      debugPrint('── Google Login ─────────────────────────────');
      debugPrint('  email : $googleEmail');

      // ── Step 1: Coba sign in Google langsung ─────────────────────────────
      UserCredential googleSignInResult;
      try {
        googleSignInResult = await _authService.signInWithCredential(
          googleCredential,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // KASUS C: Firebase mencegah pembuatan akun duplikat.
          // Tangani sama seperti KASUS B di bawah.
          debugPrint('  [auth] account-exists → perlu linking');
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

      debugPrint(
        '  isNewUser : ${googleSignInResult.additionalUserInfo?.isNewUser}',
      );
      debugPrint('  uid       : ${newUser.uid}');

      // ── Step 2: Deteksi apakah Firebase baru buat akun (KASUS B) ─────────
      if (googleSignInResult.additionalUserInfo?.isNewUser == true) {
        // Firebase membuat akun Google baru — artinya sebelumnya tidak ada
        // akun Google untuk email ini. Kemungkinan besar ada akun email+password.
        // HAPUS akun Google baru ini agar tidak ada duplikat.
        debugPrint(
          '  [auth] isNewUser=true → hapus akun Google baru, perlu linking',
        );
        try {
          await newUser.delete();
        } catch (deleteErr) {
          debugPrint('  [auth] gagal hapus akun baru: $deleteErr');
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

      // ── Step 3: KASUS A — akun sudah ada dengan Google provider ──────────
      // Cek dokumen Firestore
      final userData = await _firestoreService.getUserData(newUser.uid);
      if (userData == null) {
        debugPrint('  [firestore] dokumen uid=${newUser.uid} tidak ditemukan');
        await newUser.delete();
        await _authService.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Akun Google (${newUser.email}) belum terdaftar. '
              'Silakan daftar terlebih dahulu.';
          _isLoading = false;
        });
        return;
      }

      debugPrint('  [firestore] OK — role: ${userData['role']}');
      await _navigateToDashboard(newUser, userData);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _mapFirebaseError(error.code));
    } catch (e) {
      if (!mounted) return;
      debugPrint('  [Google login error] $e');
      setState(() => _errorMessage = 'Gagal login dengan Google. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final String? password = await _askPasswordForLinking(email);

    if (password == null || !mounted) {
      await googleSignIn.signOut();
      return;
    }

    setState(() => _isLoading = true);

    // Sign in dengan email+password
    final UserCredential emailCred;
    try {
      emailCred = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (authErr) {
      await googleSignIn.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            (authErr.code == 'invalid-credential' ||
                authErr.code == 'wrong-password')
            ? 'Password salah. Akun Google tidak bisa dihubungkan.'
            : _mapFirebaseError(authErr.code);
        _isLoading = false;
      });
      return;
    }

    // Link Google credential ke akun email+password
    try {
      await _authService.linkGoogleToCurrentUser(googleCredential);
      debugPrint('  [link] ✅ Google provider berhasil ditambahkan');
      debugPrint(
        '  [link] providers: ${emailCred.user?.providerData.map((p) => p.providerId).toList()}',
      );
    } on FirebaseAuthException catch (linkErr) {
      debugPrint('  [link] warning: ${linkErr.code}');
      if (linkErr.code == 'credential-already-in-use') {
        await _authService.signOut();
        await googleSignIn.signOut();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Akun Google ini sudah terhubung ke akun lain. '
              'Gunakan akun Google yang berbeda.';
          _isLoading = false;
        });
        return;
      }
      // Error lain — tetap lanjutkan, user sudah login via email+password
    }

    final User? user = emailCred.user;
    if (user == null || !mounted) return;

    final userData = await _firestoreService.getUserData(user.uid);
    if (userData == null) {
      await _authService.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Akun ($email) belum terdaftar. Silakan daftar terlebih dahulu.';
        _isLoading = false;
      });
      return;
    }

    await _navigateToDashboard(user, userData);
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
    final String nextRoute;
    if (role == 'superadmin' || role == 'super_admin') {
      nextRoute = '/superadmin-dashboard';
    } else if (role == 'admin') {
      nextRoute = '/admin-dashboard';
    } else {
      nextRoute = '/user-dashboard';
    }
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
