import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/cloudinary_config.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class RegistrationService {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  RegistrationService({
    AuthService? authService,
    FirestoreService? firestoreService,
  }) : _authService = authService ?? AuthService(),
       _firestoreService = firestoreService ?? FirestoreService();

  // Mengunggah satu file ke Cloudinary untuk kebutuhan registrasi.
  Future<String> uploadFile(dynamic file) async {
    if (CloudinaryConfig.cloudName == 'YOUR_CLOUD_NAME' ||
        CloudinaryConfig.uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw Exception(
        'Cloudinary belum dikonfigurasi di lib/config/cloudinary_config.dart',
      );
    }

    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/auto/upload',
      );
      final request = http.MultipartRequest('POST', url);

      List<int> bytes;
      String fileName;

      if (file is XFile) {
        bytes = await file.readAsBytes();
        fileName = file.name;
      } else if (file is PlatformFile) {
        bytes =
            file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null) ??
            [];
        if (bytes.isEmpty) {
          throw Exception('Gagal membaca file');
        }
        fileName = file.name;
      } else {
        throw Exception('Format file tidak didukung');
      }

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['secure_url'] as String;
      }

      final errorBody = jsonDecode(response.body);
      final String errorMsg =
          errorBody['error']?['message'] ??
          'Gagal mengunggah file ke Cloudinary.';
      throw Exception('Cloudinary: $errorMsg (Status ${response.statusCode})');
    } catch (e) {
      throw Exception('Gagal mengunggah berkas ke Cloudinary: ${e.toString()}');
    }
  }

  // Mendaftarkan user biasa ke Auth dan Firestore.
  // Satu email = satu akun. Jika email sudah ada di Firebase Auth
  // (via Google), password provider di-link ke akun yang sama.
  Future<void> registerRegularUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    UserCredential? credential;
    try {
      // Coba buat akun baru dengan email+password
      credential = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);
      // Akun baru — buat dokumen Firestore
      await _firestoreService.createUser(credential.user!.uid, {
        'nama': name,
        'email': email,
        'noHp': phone,
        'foto': '',
        'role': 'user',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Email sudah ada di Firebase Auth — kemungkinan akun Google.
        // Strategi: sign in Google dulu → link password provider.
        // Tapi kita tidak bisa sign in Google di sini tanpa UI.
        //
        // Alternatif yang bisa dilakukan tanpa memunculkan Google picker:
        // Cek apakah password provider sudah ada dengan mencoba sign in.
        try {
          final existing = await _authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Password provider sudah ada dan cocok.
          // Pastikan dokumen Firestore tersedia dengan data terbaru.
          await existing.user?.updateDisplayName(name);
          final firestoreData = await _firestoreService.getUserData(
            existing.user!.uid,
          );
          if (firestoreData == null) {
            // Dokumen belum ada — buat sekarang
            await _firestoreService.createUser(existing.user!.uid, {
              'nama': name,
              'email': email,
              'noHp': phone,
              'foto': existing.user?.photoURL ?? '',
              'role': 'user',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            // Update noHp dan nama jika berubah
            await _firestoreService.updateUser(existing.user!.uid, {
              'nama': name,
              'noHp': phone,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await _authService.signOut();
          return;
        } on FirebaseAuthException catch (signInErr) {
          if (signInErr.code == 'invalid-credential' ||
              signInErr.code == 'wrong-password' ||
              signInErr.code == 'user-not-found') {
            // Email ada tapi password tidak cocok → akun via Google tanpa password.
            // Arahkan user untuk login Google dulu, lalu password bisa di-link.
            throw FirebaseAuthException(
              code: 'email-google-no-password',
              message:
                  'Email $email sudah terdaftar via Google. '
                  'Silakan login menggunakan tombol Google terlebih dahulu. '
                  'Setelah login, Anda bisa mengatur password melalui profil.',
            );
          }
          rethrow;
        }
      }
      if (credential?.user != null) {
        await _deleteCreatedUser(credential!.user);
      }
      rethrow;
    } catch (e) {
      if (credential?.user != null) {
        await _deleteCreatedUser(credential!.user);
      }
      rethrow;
    }
  }

  // Mendaftarkan admin game station beserta data station ke Auth dan Firestore.
  Future<void> registerAdminStation({
    required String ownerName,
    required String businessEmail,
    required String businessPhone,
    required String password,
    required String stationName,
    required String address,
    required String stationType,
    required List<Map<String, dynamic>> operationalHours,
    required List<XFile> stationPhotoFiles,
    required List<PlatformFile> legalDocFiles,
  }) async {
    UserCredential? credential;
    try {
      credential = await _authService.createUserWithEmailAndPassword(
        email: businessEmail,
        password: password,
      );

      await credential.user?.updateDisplayName(ownerName);
      final String uid = credential.user!.uid;

      final List<String> photoUrls = await Future.wait(
        stationPhotoFiles.map(uploadFile),
      );
      final List<String> docUrls = await Future.wait(
        legalDocFiles.map(uploadFile),
      );

      await _firestoreService.registerAdminStation(
        uid,
        {
          'nama': ownerName,
          'email': businessEmail,
          'noHp': businessPhone,
          'foto': '',
          'role': 'admin',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'namaStation': stationName,
          'namaOwner': ownerName,
          'emailOwner': businessEmail,
          'noHpOwner': businessPhone,
          'ownerId': uid,
          'alamat': address,
          'jenis': stationType,
          'jamOperasional': operationalHours,
          'foto': photoUrls,
          'buktiLegalitas': docUrls,
          'rating': 0,
          'totalReview': 0,
          'totalPemasukan': 0,
          'statusVerifikasi': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await _authService.signOut();
    } catch (e) {
      if (credential?.user != null) {
        await _deleteCreatedUser(credential!.user);
      }
      await _authService.signOut();
      rethrow;
    }
  }

  Future<void> _deleteCreatedUser(User? user) async {
    if (user == null) {
      return;
    }

    try {
      await user.delete();
    } catch (e) {
      debugPrint('Gagal menghapus user setelah registrasi gagal: $e');
    }
  }
}
