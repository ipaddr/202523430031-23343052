import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../../config/cloudinary_config.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/background.dart';

// Halaman registrasi untuk user biasa dan admin station.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _stationNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _roomsController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isAdminMode = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _acceptTerms = false;
  String? _selectedStationType;
  String? _errorMessage;

  final List<XFile> _stationPhotoFiles = [];
  final List<PlatformFile> _legalDocFiles = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _stationTypes = const [
    'Gaming Center',
    'Esports Arena',
    'Racing Room',
    'VR Station',
    'Console Lounge',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _stationNameController.dispose();
    _ownerNameController.dispose();
    _businessEmailController.dispose();
    _businessPhoneController.dispose();
    _roomsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String get _pageTitle =>
      _isAdminMode ? 'Daftar Admin Game Station' : 'Daftar Pengguna';

  String get _headline =>
      _isAdminMode ? 'Buat Profil Bisnis' : 'Buat Akun Baru';

  String get _subtitle => _isAdminMode
      ? 'Lengkapi data untuk mendaftarkan Game Station Anda di komunitas GameZone.'
      : 'Bergabunglah dengan komunitas gaming terbesar.';

  String get _buttonText => _isAdminMode ? 'Kirim Pendaftaran' : 'Daftar';

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _pickStationPhoto() async {
    // Pilih foto station dari galeri dengan kompresi ringan.
    _clearError();
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 40,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (images.isNotEmpty) {
        setState(() {
          _stationPhotoFiles.addAll(images);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memilih foto stasiun game.';
      });
    }
  }

  Future<void> _pickLegalDocument() async {
    // Pilih dokumen legalitas yang akan diunggah ke Cloudinary.
    _clearError();
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        // Filter out files larger than 10 MB to prevent extremely large uploads
        final List<PlatformFile> filteredFiles = result.files
            .where((file) => file.size < 10 * 1024 * 1024)
            .toList();

        if (filteredFiles.length < result.files.length) {
          setState(() {
            _errorMessage =
                'Beberapa file dilewati karena melebihi batas 10 MB.';
          });
        }

        setState(() {
          _legalDocFiles.addAll(filteredFiles);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memilih dokumen legalitas.';
      });
    }
  }

  void _removeStationPhoto(int index) {
    setState(() {
      _stationPhotoFiles.removeAt(index);
    });
  }

  void _removeLegalDocument(int index) {
    setState(() {
      _legalDocFiles.removeAt(index);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<String> _uploadFile(dynamic file) async {
    // Upload file dipakai ulang untuk foto dan dokumen.
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
        if (bytes.isEmpty) throw Exception('Gagal membaca file');
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

  Future<void> _submit() async {
    // Submit memisahkan alur registrasi user dan admin station.
    FocusScope.of(context).unfocus();
    _clearError();

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Silakan setujui syarat dan kebijakan terlebih dahulu.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isAdminMode) {
      if (_stationPhotoFiles.isEmpty) {
        setState(() {
          _errorMessage = 'Foto Game Station wajib diunggah.';
        });
        return;
      }
      if (_legalDocFiles.isEmpty) {
        setState(() {
          _errorMessage = 'Bukti Legalitas / Izin wajib diunggah.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    User? createdUser;
    try {
      if (_isAdminMode) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _businessEmailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        createdUser = credential.user;

        await credential.user?.updateDisplayName(
          _ownerNameController.text.trim(),
        );
        final String uid = credential.user!.uid;

        final db = FirebaseFirestore.instance;
        final ownerRef = db.collection('users').doc(uid);
        final stationRef = db.collection('stations').doc();

        // Upload photos in parallel
        final List<Future<String>> photoUploadFutures = [];
        for (int i = 0; i < _stationPhotoFiles.length; i++) {
          final file = _stationPhotoFiles[i];
          photoUploadFutures.add(_uploadFile(file));
        }
        final List<String> photoUrls = await Future.wait(photoUploadFutures);

        // Upload documents in parallel
        final List<Future<String>> docUploadFutures = [];
        for (int i = 0; i < _legalDocFiles.length; i++) {
          final file = _legalDocFiles[i];
          docUploadFutures.add(_uploadFile(file));
        }
        final List<String> docUrls = await Future.wait(docUploadFutures);

        final batch = db.batch();
        batch.set(ownerRef, {
          'nama': _ownerNameController.text.trim(),
          'email': _businessEmailController.text.trim(),
          'noHp': _businessPhoneController.text.trim(),
          'foto': '',
          'role': 'admin',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(stationRef, {
          'namaStation': _stationNameController.text.trim(),
          'namaOwner': _ownerNameController.text.trim(),
          'emailOwner': _businessEmailController.text.trim(),
          'noHpOwner': _businessPhoneController.text.trim(),
          'ownerId': uid,
          'alamat': _addressController.text.trim(),
          'jenis': _selectedStationType ?? '',
          'foto': photoUrls,
          'buktiLegalitas': docUrls,
          'jumlahRooms': int.tryParse(_roomsController.text.trim()) ?? 0,
          'rating': 0,
          'totalReview': 0,
          'totalPemasukan': 0,
          'statusVerifikasi': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();

        // Sign out because createUserWithEmailAndPassword automatically signs in the user
        await FirebaseAuth.instance.signOut();

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran admin terkirim. Menunggu verifikasi.'),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        createdUser = credential.user;

        await credential.user?.updateDisplayName(_nameController.text.trim());
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'nama': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'noHp': _phoneController.text.trim(),
              'foto': '',
              'role': 'user',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacementNamed('/user-dashboard');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapFirebaseError(error.code);
      });
    } catch (e) {
      // Rollback Auth User if database write fails to prevent orphaned Auth account
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (deleteError) {
          debugPrint('Gagal menghapus user setelah error: $deleteError');
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        final String errorStr = e.toString();
        if (errorStr.contains('Exception:')) {
          _errorMessage = errorStr.substring(
            errorStr.indexOf('Exception:') + 10,
          );
        } else {
          _errorMessage = 'Gagal menyimpan pendaftaran: $errorStr';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _mapFirebaseError(String code) {
    // Ubah kode error Firebase ke pesan yang lebih mudah dipahami.
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'operation-not-allowed':
        return 'Registrasi belum diaktifkan.';
      default:
        return 'Registrasi gagal. Periksa kembali data yang diisi.';
    }
  }

  Widget _sectionHeader() {
    // Header ringkas di atas form.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headline,
          style: AppTextStyle.h2.copyWith(fontSize: 28, color: AppColors.white),
        ),
        const SizedBox(height: 8),
        Text(
          _subtitle,
          style: const TextStyle(
            color: Color(0xFF9AA3C3),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _userForm() {
    // Form ini dipakai saat mode user aktif.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthFieldLabel(text: 'NAMA LENGKAP'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _nameController,
          hintText: 'Masukkan nama lengkap',
          prefixIcon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nama lengkap wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'EMAIL'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _emailController,
          hintText: 'contoh@email.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final input = (value ?? '').trim();
            if (input.isEmpty) return 'Email wajib diisi.';
            if (!input.contains('@')) return 'Format email tidak valid.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'NOMOR TELEPON'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _phoneController,
          hintText: '0812xxxxxxxx',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nomor telepon wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'KATA SANDI'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _passwordController,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
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
          validator: (value) {
            if ((value ?? '').trim().length < 6) {
              return 'Password minimal 6 karakter.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _adminForm() {
    // Form ini dipakai saat mode admin station aktif.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthFieldLabel(text: 'NAMA GAME STATION'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _stationNameController,
          hintText: 'Masukkan nama tempat',
          prefixIcon: Icons.storefront_outlined,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nama game station wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'NAMA PEMILIK'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _ownerNameController,
          hintText: 'Nama lengkap owner',
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nama pemilik wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'EMAIL BISNIS'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _businessEmailController,
          hintText: 'contoh@gamestation.com',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final input = (value ?? '').trim();
            if (input.isEmpty) return 'Email bisnis wajib diisi.';
            if (!input.contains('@')) return 'Format email tidak valid.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'NOMOR HP / WHATSAPP'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _businessPhoneController,
          hintText: '0812xxxxxxxx',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Nomor telepon wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'JENIS GAME STATION'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedStationType,
          items: _stationTypes
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedStationType = value;
            });
          },
          decoration: const InputDecoration(hintText: 'Pilih jenis'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Jenis game station wajib dipilih.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'JUMLAH ROOM / PC'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _roomsController,
          hintText: 'Contoh: 15',
          prefixIcon: Icons.tag_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Jumlah room/PC wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'ALAMAT LENGKAP'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          maxLines: 3,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: 'Masukkan alamat detail...',
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Alamat lengkap wajib diisi.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'FOTO GAME STATION'),
        const SizedBox(height: 8),
        _stationPhotoFiles.isEmpty
            ? _UploadBox(
                title: 'Upload Foto Utama',
                subtitle: 'PNG/JPG (Bisa pilih lebih dari 1)',
                icon: Icons.camera_alt_outlined,
                onTap: _pickStationPhoto,
              )
            : _buildPhotoList(),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'BUKTI LEGALITAS / IZIN'),
        const SizedBox(height: 8),
        _legalDocFiles.isEmpty
            ? _UploadBox(
                title: 'Upload Dokumen (PDF/JPG)',
                subtitle:
                    'Izin usaha atau dokumen pendukung (Bisa pilih lebih dari 1)',
                icon: Icons.description_outlined,
                onTap: _pickLegalDocument,
              )
            : _buildLegalDocsList(),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'KATA SANDI'),
        const SizedBox(height: 8),
        AuthGameZoneField(
          controller: _passwordController,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
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
          validator: (value) {
            if ((value ?? '').trim().length < 6) {
              return 'Password minimal 6 karakter.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const _InfoCard(
          text:
              'Catatan: Data akan diverifikasi oleh super admin dalam 1x24 jam sebelum akun aktif dan muncul di pencarian.',
        ),
      ],
    );
  }

  Widget _buildPhotoList() {
    // Daftar foto station tampil horizontal dengan tombol tambah.
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stationPhotoFiles.length + 1,
        itemBuilder: (context, index) {
          if (index == _stationPhotoFiles.length) {
            return GestureDetector(
              onTap: _pickStationPhoto,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF11182D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: Color(0xFF22D3EE),
                      size: 24,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tambah',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final file = _stationPhotoFiles[index];
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  image: DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 14,
                child: GestureDetector(
                  onTap: () => _removeStationPhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegalDocsList() {
    // Daftar dokumen legalitas ditampilkan sebagai list kartu.
    return Column(
      children: [
        ...List.generate(_legalDocFiles.length, (index) {
          final file = _legalDocFiles[index];
          final String extension = file.extension?.toLowerCase() ?? '';
          final IconData docIcon = extension == 'pdf'
              ? Icons.picture_as_pdf_rounded
              : Icons.description_rounded;
          final Color iconColor = extension == 'pdf'
              ? const Color(0xFFEF4444)
              : const Color(0xFF22D3EE);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF11182D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(docIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(file.size),
                        style: const TextStyle(
                          color: Color(0xFF8F97B6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeLegalDocument(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickLegalDocument,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF11182D).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFF22D3EE),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Tambah Dokumen Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggleRole(bool value) {
    // Ganti mode registrasi antara user dan admin.
    setState(() {
      _isAdminMode = value;
      _errorMessage = null;
    });
  }

  void _goToLogin() {
    // Kembali ke halaman login dari form registrasi.
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Layout utama berisi header, switch role, form, dan tombol aksi.
    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sticky Header (Back Button & Title)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _goToLogin,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141B31),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF23304C),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pageTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Scrollable Content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionHeader(),
                                  const SizedBox(height: 18),
                                  AuthRoleSwitch(
                                    isAdminMode: _isAdminMode,
                                    onChanged: _toggleRole,
                                  ),
                                  const SizedBox(height: 18),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: _errorMessage == null
                                        ? const SizedBox.shrink()
                                        : AuthErrorBanner(
                                            key: ValueKey(_errorMessage),
                                            message: _errorMessage!,
                                          ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: _isAdminMode
                                        ? _adminForm()
                                        : _userForm(),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: _acceptTerms,
                                          onChanged: (value) {
                                            setState(() {
                                              _acceptTerms = value ?? false;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            _isAdminMode
                                                ? 'Dengan mendaftar, saya menyetujui proses verifikasi dan kebijakan privasi GameZone.'
                                                : 'Dengan mendaftar, saya menyetujui Syarat & Ketentuan serta Kebijakan Privasi GameZone.',
                                            style: const TextStyle(
                                              color: Color(0xFF8F97B6),
                                              fontSize: 11,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  AuthPrimaryButton(
                                    isLoading: _isSubmitting,
                                    onPressed: _submit,
                                    text: _buttonText,
                                  ),
                                  const SizedBox(height: 16),
                                  AuthFooterPrompt(
                                    onTap: _goToLogin,
                                    prefixText: 'Sudah ada akun? ',
                                    actionText: 'Login',
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _UploadBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kotak upload sederhana untuk memilih file baru.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF11182D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF22D3EE), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8F97B6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF8F97B6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    // Catatan kecil di bawah form untuk memberi konteks tambahan.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11182D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF253151)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9AA3C3),
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
