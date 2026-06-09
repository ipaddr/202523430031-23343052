import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mendapatkan data pengguna yang sedang masuk
  User? getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      final providers = user.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (getCurrentUser): ${providers.join(', ')}");
    }
    return user;
  }

  // Menunggu sesi auth benar-benar siap jika currentUser belum terbaca saat awal.
  Future<User?> resolveCurrentUser({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      final providers = currentUser.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (resolveCurrentUser): ${providers.join(', ')}");
      return currentUser;
    }

    try {
      final resolved = await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);
      if (resolved != null) {
        final providers = resolved.providerData.map((p) => p.providerId).toList();
        debugPrint("ACTIVE PROVIDERS (resolveCurrentUser resolved): ${providers.join(', ')}");
      }
      return resolved;
    } catch (_) {
      return null;
    }
  }

  // Masuk menggunakan email dan password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null) {
      final providers = cred.user!.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (signInWithEmailAndPassword): ${providers.join(', ')}");
    }
    return cred;
  }

  // Masuk menggunakan akun Google
  Future<UserCredential> signInWithGoogle({
    GoogleSignInAccount? googleUser,
  }) async {
    GoogleSignInAccount? user = googleUser;
    if (user == null) {
      await _googleSignIn.signOut();
      user = await _googleSignIn.signIn();
    }
    if (user == null) {
      throw FirebaseAuthException(
        code: 'sign-in-aborted',
        message: 'Proses login dibatalkan oleh pengguna.',
      );
    }

    final GoogleSignInAuthentication googleAuth = await user.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    if (cred.user != null) {
      final providers = cred.user!.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (signInWithGoogle): ${providers.join(', ')}");
    }
    return cred;
  }

  /// Membangun Google OAuthCredential dari GoogleSignInAccount tanpa
  /// langsung sign in ke Firebase Auth.
  Future<OAuthCredential> buildGoogleCredential(
    GoogleSignInAccount googleUser,
  ) async {
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  /// Link Google credential ke akun yang sedang aktif (sudah sign in).
  /// Digunakan saat user sudah login email+password dan ingin tambah Google.
  Future<void> linkGoogleToCurrentUser(OAuthCredential googleCredential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Tidak ada user yang sedang login.',
      );
    }
    try {
      await user.linkWithCredential(googleCredential);
      final providers = user.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (linkGoogleToCurrentUser): ${providers.join(', ')}");
    } on FirebaseAuthException catch (e) {
      // provider-already-linked: Google sudah ter-link → tidak masalah
      // credential-already-in-use: credential Google ini sudah dipakai akun lain
      if (e.code == 'provider-already-linked') return;
      rethrow;
    }
  }

  /// Link Password credential ke akun yang sedang aktif (sudah sign in).
  /// Digunakan saat user sudah login Google dan ingin tambah password.
  Future<void> linkPasswordToCurrentUser({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Tidak ada user yang sedang login.',
      );
    }
    final credential = EmailAuthProvider.credential(email: email, password: password);
    try {
      await user.linkWithCredential(credential);
      final providers = user.providerData.map((p) => p.providerId).toList();
      debugPrint("ACTIVE PROVIDERS (linkPasswordToCurrentUser): ${providers.join(', ')}");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') return;
      rethrow;
    }
  }

  // Mendaftar akun baru dengan email dan password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Mengirim email untuk reset password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Mengambil metode masuk yang tersedia untuk email tertentu
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    // ignore: deprecated_member_use
    return await _auth.fetchSignInMethodsForEmail(email);
  }

  // Masuk menggunakan kredensial pihak ketiga (seperti Google)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  // Keluar dari sesi masuk saat ini (Firebase + Google Sign-In).
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Logout lengkap: signOut + hapus flag onboarding di SharedPreferences.
  // Gunakan method ini dari semua titik logout agar alur startup konsisten:
  // Splash → Onboarding → Login.
  Future<void> logout() async {
    await signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('seenOnboarding');
    } catch (_) {}
  }
}
