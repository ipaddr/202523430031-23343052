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
    } catch (_) {
      if (!mounted) {
        return;
      }
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
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
        return 'Email belum terdaftar.';
      case 'wrong-password':
        return 'Password salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      default:
        return 'Login gagal. Periksa kembali email dan password.';
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
    // Login Google tetap menjaga aturan akun email-password yang sudah ada.
    if (_isLoading) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn();
      // Selalu lakukan signOut terlebih dahulu dari GoogleSignIn untuk memaksa munculnya dialog pemilihan akun (account chooser)
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final email = googleUser.email;

      // ignore: deprecated_member_use
      List<String> signInMethods = [];
      try {
        // ignore: deprecated_member_use
        signInMethods = await _authService.fetchSignInMethodsForEmail(
          email,
        );
      } catch (e) {
        debugPrint('Gagal memeriksa metode sign in: $e');
      }

      if (signInMethods.isNotEmpty) {
        if (signInMethods.contains('password') &&
            !signInMethods.contains('google.com')) {
          // Pengguna terdaftar dengan Email & Password tetapi belum menghubungkan akun Google.
          // Kita cegah login Google agar password mereka tidak dihapus secara otomatis oleh Firebase.
          await googleSignIn.signOut();
          setState(() {
            _errorMessage =
                'Akun ($email) terdaftar menggunakan Email & Password. Silakan masuk menggunakan Email & Password Anda.';
            _isLoading = false;
          });
          return;
        }
      }

      // Login ke Firebase Auth terlebih dahulu agar pengguna terautentikasi.
      // Hal ini diperlukan agar kita memiliki hak akses (read permission) ke Firestore.
      final userCredential = await _authService.signInWithGoogle(googleUser: googleUser);
      final user = userCredential.user;
 
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Gagal mendapatkan data pengguna dari Google.',
        );
      }
 
      // Pengecekan pendaftaran di Firestore menggunakan UID pengguna yang telah terautentikasi
      final userData = await _firestoreService.getUserData(user.uid);
 
      if (userData == null) {
        // Jika belum terdaftar di Firestore, batalkan login.
        // Hapus akun di Firebase Auth jika ini adalah pengguna baru agar tidak meninggalkan data kosong (orphaned account).
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          try {
            await user.delete();
          } catch (deleteError) {
            debugPrint(
              'Gagal membersihkan user Auth setelah cek registrasi: $deleteError',
            );
          }
        }
        await _authService.signOut();
        setState(() {
          _errorMessage =
              'Akun Google Anda (${user.email}) belum terdaftar. Silakan daftar terlebih dahulu.';
          _isLoading = false;
        });
        return;
      }
 
      // Ambil data peran dan status dari Firestore
      final role = userData['role'] as String? ?? 'user';
      final status = userData['status'] as String? ?? 'active';
 
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
          _errorMessage = 'Pendaftaran Admin Anda ditolak oleh Super Admin.';
          _isLoading = false;
        });
        return;
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
      setState(() {
        _errorMessage =
            'Gagal melakukan login dengan Google. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
