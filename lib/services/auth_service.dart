import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mendapatkan data pengguna yang sedang masuk
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Menunggu sesi auth benar-benar siap jika currentUser belum terbaca saat awal.
  Future<User?> resolveCurrentUser({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  // Masuk menggunakan email dan password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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

    return await _auth.signInWithCredential(credential);
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

  // Keluar dari sesi masuk saat ini
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
