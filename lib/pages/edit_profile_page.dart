import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';
import '../styles/app_colors.dart';
import '../styles/app_textstyle.dart';
import '../widgets/background.dart';

// Halaman untuk mengubah profil pengguna yang sedang login.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _fotoProfilController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _fotoProfilController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Muat data profil awal dari dokumen user aktif.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _namaController.text = data['nama'] ?? '';
            _noHpController.text = data['noHp'] ?? '';
            _fotoProfilController.text = data['foto'] ?? '';
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isFetching = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<String> _uploadFile(XFile file) async {
    // Upload foto profil dilakukan melalui Cloudinary.
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

      final bytes = await file.readAsBytes();
      final fileName = file.name;

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['secure_url'] as String;
      } else {
        final errorBody = jsonDecode(response.body);
        final String errorMsg =
            errorBody['error']?['message'] ??
            'Gagal mengunggah file ke Cloudinary.';
        throw Exception(
          'Cloudinary: $errorMsg (Status ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Gagal mengunggah berkas ke Cloudinary: ${e.toString()}');
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    // Pilih gambar lalu unggah langsung agar field foto terbarui cepat.
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 40,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengunggah foto...'),
              backgroundColor: AppColors.infoBlue,
              duration: Duration(seconds: 2),
            ),
          );
        }

        final String secureUrl = await _uploadFile(image);

        setState(() {
          _fotoProfilController.text = secureUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil diunggah!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengunggah foto: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPickerOptions(BuildContext context) {
    // Bottom sheet ini memberi pilihan galeri atau kamera.
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Ambil dari Kamera',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    // Simpan perubahan profil ke Firestore setelah validasi selesai.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nama': _namaController.text.trim(),
          'noHp': _noHpController.text.trim(),
          'foto': _fotoProfilController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan data: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Profil',
                      style: AppTextStyle.h3.copyWith(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isFetching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Column(
                                      children: [
                                        GestureDetector(
                                          onTap: _isLoading
                                              ? null
                                              : () =>
                                                    _showPickerOptions(context),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 100,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.accentCyan,
                                                    width: 2,
                                                  ),
                                                  color: const Color(
                                                    0xFF141B31,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors
                                                          .accentCyan
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      blurRadius: 14,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child:
                                                    _fotoProfilController.text
                                                        .trim()
                                                        .isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              50,
                                                            ),
                                                        child: Image.network(
                                                          _fotoProfilController
                                                              .text
                                                              .trim(),
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) => const Icon(
                                                                Icons.person,
                                                                color: Color(
                                                                  0xFF64748B,
                                                                ),
                                                                size: 44,
                                                              ),
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.person,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                        size: 44,
                                                      ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: AppColors
                                                            .accentCyan,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.camera_alt_rounded,
                                                    color: Colors.black,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : () =>
                                                    _showPickerOptions(context),
                                          icon: const Icon(
                                            Icons.camera_alt_outlined,
                                            color: AppColors.accentCyan,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Ubah Foto Profil',
                                            style: TextStyle(
                                              color: AppColors.accentCyan,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            backgroundColor: AppColors
                                                .accentCyan
                                                .withValues(alpha: 0.1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Field Nama
                                  const Text(
                                    'NAMA LENGKAP',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _namaController,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Nama tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan nama lengkap',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF141B31),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF24304A),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF24304A),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: AppColors.accentCyan,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Field No HP
                                  const Text(
                                    'NOMOR HP',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _noHpController,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Nomor HP tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan nomor HP aktif',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.phone_android_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF141B31),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF24304A),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF24304A),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: AppColors.accentCyan,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  const SizedBox(height: 16),

                                  // Tombol Simpan
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accentCyan,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.black),
                                              ),
                                            )
                                          : const Text(
                                              'Simpan Perubahan',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
