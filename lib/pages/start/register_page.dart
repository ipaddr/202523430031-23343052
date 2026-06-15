import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../widgets/common/auth_widgets.dart';
import '../../widgets/common/background.dart';
import '../../services/registration_service.dart';

// Halaman registrasi untuk user biasa dan admin station.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const List<String> _operationalDayLabels = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  final RegistrationService _registrationService = RegistrationService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Data form pendaftaran game station
  final _stationNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isAdminMode = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _acceptTerms = false;
  String? _selectedStationType;
  String? _errorMessage;

  late final List<_OperationalScheduleItem> _operationalScheduleItems =
      List.generate(
        _operationalDayLabels.length,
        (index) => _OperationalScheduleItem(
          dayLabel: _operationalDayLabels[index],
          isOpen: true,
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 22, minute: 0),
        ),
      );

  final List<XFile> _stationPhotoFiles = [];
  final List<PlatformFile> _legalDocFiles = [];
  final ImagePicker _picker = ImagePicker();

  // Daftar kategori game station yang tersedia
  final List<String> _stationTypes = const [
    'Gaming Center',
    'Esports Center',
    'Console Center',
    'VR Center',
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

  Future<void> _showPopupMessage({
    required String title,
    required String message,
    bool isError = true,
  }) async {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF11182D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isError
                  ? const Color(0xFFEF4444).withValues(alpha: 0.45)
                  : const Color(0xFF22D3EE).withValues(alpha: 0.35),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFFD5DBF2), height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );

    FocusManager.instance.primaryFocus?.unfocus();
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
      await _showPopupMessage(
        title: 'Gagal memilih foto',
        message: 'Gagal memilih foto stasiun game.',
      );
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
        // Saring berkas yang lebih besar dari 10 MB untuk mencegah unggahan berkas yang terlalu besar
        final List<PlatformFile> filteredFiles = result.files
            .where((file) => file.size < 10 * 1024 * 1024)
            .toList();

        if (filteredFiles.length < result.files.length) {
          await _showPopupMessage(
            title: 'Ukuran file terlalu besar',
            message: 'Beberapa file dilewati karena melebihi batas 10 MB.',
            isError: false,
          );
        }

        setState(() {
          _legalDocFiles.addAll(filteredFiles);
        });
      }
    } catch (e) {
      await _showPopupMessage(
        title: 'Gagal memilih dokumen',
        message: 'Gagal memilih dokumen legalitas.',
      );
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

  Future<void> _submit() async {
    // Submit memisahkan alur registrasi user dan admin station.
    FocusScope.of(context).unfocus();
    _clearError();

    if (!_acceptTerms) {
      await _showPopupMessage(
        title: 'Syarat belum disetujui',
        message: 'Silakan setujui syarat dan kebijakan terlebih dahulu.',
      );
      return;
    }

    // Validasi form sebelum submit
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isAdminMode) {
      if (_stationPhotoFiles.isEmpty) {
        await _showPopupMessage(
          title: 'Foto utama belum ada',
          message: 'Foto Utama Game Station wajib diunggah.',
        );
        return;
      }
      if (_legalDocFiles.isEmpty) {
        await _showPopupMessage(
          title: 'Dokumen legalitas belum ada',
          message: 'Bukti Legalitas / Izin wajib diunggah.',
        );
        return;
      }
      final List<Map<String, dynamic>> operationalHoursPayload =
          _buildOperationalHoursPayload();
      if (operationalHoursPayload.isEmpty) {
        await _showPopupMessage(
          title: 'Jadwal operasional kosong',
          message: 'Minimal satu hari operasional harus dipilih.',
        );
        return;
      }
      for (final item in _operationalScheduleItems) {
        if (!item.isOpen) continue;
        if (!_isEndTimeAfterStartTime(item.startTime, item.endTime)) {
          await _showPopupMessage(
            title: 'Jam operasional tidak valid',
            message:
                'Jam tutup harus lebih besar dari jam buka untuk ${item.dayLabel}.',
          );
          return;
        }
      }
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      if (_isAdminMode) {
        await _registrationService.registerAdminStation(
          ownerName: _ownerNameController.text.trim(),
          businessEmail: _businessEmailController.text.trim(),
          businessPhone: _businessPhoneController.text.trim(),
          password: _passwordController.text.trim(),
          stationName: _stationNameController.text.trim(),
          address: _addressController.text.trim(),
          stationType: _selectedStationType ?? '',
          operationalHours: _buildOperationalHoursPayload(),
          stationPhotoFiles: _stationPhotoFiles,
          legalDocFiles: _legalDocFiles,
        );

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
        await _registrationService.registerRegularUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacementNamed('/user-dashboard');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      await _showPopupMessage(
        title: 'Registrasi gagal',
        message: _mapFirebaseError(error.code),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final String errorStr = e.toString();
      final String message = errorStr.contains('Exception:')
          ? errorStr.substring(errorStr.indexOf('Exception:') + 10)
          : 'Gagal menyimpan pendaftaran: $errorStr';
      await _showPopupMessage(title: 'Registrasi gagal', message: message);
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
        return 'Email sudah terdaftar. Silakan gunakan email lain.';
      case 'email-google-no-password':
        // Kasus khusus: email terdaftar via Google, belum ada password provider
        return 'Email ini terdaftar via Google. Silakan login menggunakan tombol Google, '
            'atau gunakan "Lupa Password" di halaman login untuk mengatur password.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'operation-not-allowed':
        return 'Registrasi belum diaktifkan. Hubungi administrator.';
      default:
        return 'Registrasi gagal. Periksa kembali data yang diisi.';
    }
  }

  Widget _sectionHeader() {

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
        const AuthFieldLabel(text: 'JAM OPERASIONAL'),
        const SizedBox(height: 8),
        _buildOperationalHoursEditor(),
        const SizedBox(height: 14),
        const AuthFieldLabel(text: 'FOTO UTAMA GAME STATION'),
        const SizedBox(height: 8),
        _stationPhotoFiles.isEmpty
            ? _UploadBox(
                title: 'Foto Utama Game Station',
                subtitle:
                    'Upload foto tampilan utama Game Station yang akan ditampilkan kepada pengguna.',
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
                    'Izin usaha / Dokumen Pendukung (Bisa pilih lebih dari 1)',
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
              'Catatan: Data akan diverifikasi oleh Super Admin sebelum Game Station tampil di aplikasi.',
        ),
      ],
    );
  }

  Widget _buildPhotoList() {
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

  Widget _buildOperationalHoursEditor() {
    // Jadwal operasional dibuat per hari agar admin bisa memilih hari dan rentang jam.
    return Column(
      children: [
        for (var index = 0; index < _operationalScheduleItems.length; index++)
          _buildOperationalDayCard(index),
      ],
    );
  }

  Widget _buildOperationalDayCard(int index) {
    final item = _operationalScheduleItems[index];
    final String startText = _formatTimeOfDay(item.startTime);
    final String endText = _formatTimeOfDay(item.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF11182D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Switch(
                value: item.isOpen,
                onChanged: (value) {
                  setState(() {
                    item.isOpen = value;
                  });
                },
                activeThumbColor: AppColors.accentCyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.dayLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                item.isOpen ? 'Buka' : 'Tutup',
                style: TextStyle(
                  color: item.isOpen
                      ? const Color(0xFF22D3EE)
                      : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (item.isOpen) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerButton(
                    label: 'Buka',
                    valueText: startText,
                    onTap: () => _pickOperationalTime(index, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTimePickerButton(
                    label: 'Tutup',
                    valueText: endText,
                    onTap: () => _pickOperationalTime(index, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerButton({
    required String label,
    required String valueText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141B31),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF24304A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOperationalTime(int index, bool isStart) async {
    final item = _operationalScheduleItems[index];
    final TimeOfDay initialTime = isStart ? item.startTime : item.endTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: const TimePickerThemeData(
                backgroundColor: Color(0xFF0F172A),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      item.isOpen = true;
      if (isStart) {
        item.startTime = picked;
      } else {
        item.endTime = picked;
      }
    });
  }

  List<Map<String, dynamic>> _buildOperationalHoursPayload() {
    return _operationalScheduleItems
        .where((item) => item.isOpen)
        .map(
          (item) => {
            'hari': item.dayLabel,
            'buka': _formatTimeOfDay(item.startTime),
            'tutup': _formatTimeOfDay(item.endTime),
            'isOpen': item.isOpen,
          },
        )
        .toList();
  }

  bool _isEndTimeAfterStartTime(TimeOfDay start, TimeOfDay end) {
    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;
    return endMinutes > startMinutes;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour.$minute';
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

  Widget _buildPageHeader() {

    return Padding(
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141B31),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF23304C)),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 20,
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
    );
  }

  Widget _buildModeSwitcher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthRoleSwitch(isAdminMode: _isAdminMode, onChanged: _toggleRole),
      ],
    );
  }

  Widget _buildFormSwitcher() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isAdminMode ? _adminForm() : _userForm(),
    );
  }

  Widget _buildTermsSection() {
    // Bagian persetujuan syarat dan kebijakan dipisah agar alur form lebih rapi.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            padding: const EdgeInsets.only(top: 2),
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
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildScrollableContent() {
    // Konten utama dibuat scrollable agar form panjang tetap nyaman di layar kecil.
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                        _buildModeSwitcher(),
                        const SizedBox(height: 18),
                        _buildFormSwitcher(),
                        const SizedBox(height: 18),
                        _buildTermsSection(),
                        const SizedBox(height: 18),
                        _buildActionsSection(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layout utama tetap sama, hanya dipecah ke helper private agar lebih rapi.
    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildPageHeader(), _buildScrollableContent()],
          ),
        ),
      ),
    );
  }
}

class _OperationalScheduleItem {
  final String dayLabel;
  bool isOpen;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _OperationalScheduleItem({
    required this.dayLabel,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
  });
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
