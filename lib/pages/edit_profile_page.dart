import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config/cloudinary_config.dart';
import '../services/firestore_service.dart';
import '../styles/app_colors.dart';
import '../widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

// Halaman untuk mengubah profil pengguna yang sedang login.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
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

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _fotoProfilController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isFetching = true;
  Map<String, dynamic>? _stationData;
  String _currentRole = 'user';
  String _initialPhotoUrl = '';
  static const List<String> _operationalDayLabels = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  // Jadwal operasional per-hari untuk admin; diisi saat _loadUserData()
  final List<_OperationalScheduleItem> _operationalScheduleItems = [];

  Future<void> _closePage(BuildContext context, {bool saved = false}) async {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, saved);
      return;
    }

    final String fallbackRoute = _currentRole == 'admin'
        ? '/admin-dashboard'
        : _currentRole == 'superadmin' || _currentRole == 'super_admin'
        ? '/superadmin-dashboard'
        : '/user-dashboard';

    if (!context.mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, fallbackRoute, (route) => false);
  }

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
    final user = _authService.getCurrentUser();
    if (user != null) {
      try {
        final data = await _firestoreService.getUserData(user.uid);
        if (data != null) {
          final String role = (data['role'] ?? 'user').toString().toLowerCase();
          Map<String, dynamic>? stationData;

          // Admin disinkronkan dengan station milik owner yang sedang login.
          if (role == 'admin') {
            stationData = await _firestoreService.getStationByOwnerId(
              user.uid,
              email: user.email,
              name: user.displayName,
            );
          }

          final String userPhotoUrl = _extractPhotoUrl(data['foto']);
          final String stationPhotoUrl = role == 'admin'
              ? _extractPhotoUrl(stationData?['foto'])
              : '';
          final String resolvedPhotoUrl = userPhotoUrl.isNotEmpty
              ? userPhotoUrl
              : (stationPhotoUrl.isNotEmpty
                    ? stationPhotoUrl
                    : (user.photoURL ?? ''));

          setState(() {
            _currentRole = role;
            _stationData = stationData;
            _namaController.text = data['nama'] ?? '';
            _noHpController.text = data['noHp'] ?? '';
            _initialPhotoUrl = resolvedPhotoUrl;
            _fotoProfilController.text = resolvedPhotoUrl;
          });
          // Inisialisasi jam operasional jika role admin.
          if (role == 'admin') {
            _operationalScheduleItems.clear();
            final dynamic jamOp = stationData?['jamOperasional'];
            if (jamOp is List && jamOp.isNotEmpty) {
              // Map existing data per hari jika tersedia.
              for (final label in _operationalDayLabels) {
                final match = jamOp.firstWhere(
                  (e) => (e is Map && (e['hari'] ?? '') == label),
                  orElse: () => null,
                );
                if (match is Map) {
                  final String buka = (match['buka'] ?? '10.00').toString();
                  final String tutup = (match['tutup'] ?? '22.00').toString();
                  final bool isOpen = (match['isOpen'] ?? true) as bool;
                  _operationalScheduleItems.add(
                    _OperationalScheduleItem(
                      dayLabel: label,
                      isOpen: isOpen,
                      startTime: _parseTimeOfDay(buka),
                      endTime: _parseTimeOfDay(tutup),
                    ),
                  );
                } else {
                  _operationalScheduleItems.add(
                    _OperationalScheduleItem(
                      dayLabel: label,
                      isOpen: true,
                      startTime: const TimeOfDay(hour: 10, minute: 0),
                      endTime: const TimeOfDay(hour: 22, minute: 0),
                    ),
                  );
                }
              }
            } else {
              // Default jika tidak ada data jadwal.
              _operationalScheduleItems.addAll(
                List.generate(
                  _operationalDayLabels.length,
                  (index) => _OperationalScheduleItem(
                    dayLabel: _operationalDayLabels[index],
                    isOpen: true,
                    startTime: const TimeOfDay(hour: 10, minute: 0),
                    endTime: const TimeOfDay(hour: 22, minute: 0),
                  ),
                ),
              );
            }
          }
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

    final user = _authService.getCurrentUser();
    if (user != null) {
      try {
        if (_currentRole == 'admin') {
          for (final item in _operationalScheduleItems) {
            if (!item.isOpen) continue;
            if (!_isEndTimeAfterStartTime(item.startTime, item.endTime)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Jam tutup harus lebih besar dari jam buka untuk ${item.dayLabel}.',
                    ),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
              setState(() {
                _isLoading = false;
              });
              return;
            }
          }
        }

        final String photoUrl = _firstNonEmptyString([
          _fotoProfilController.text.trim(),
          _initialPhotoUrl,
          user.photoURL,
        ]);
        final Map<String, dynamic> userUpdates = {
          'nama': _namaController.text.trim(),
          'noHp': _noHpController.text.trim(),
          'foto': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestoreService.updateUser(user.uid, {...userUpdates});

        // Admin: hanya sinkronkan field non-sensitif ke dokumen station.
        //
        // Field yang DIIZINKAN untuk diperbarui tanpa verifikasi superadmin:
        // - namaOwner (nama pemilik)
        // - noHpOwner (nomor HP pemilik)
        // - foto (hanya foto profil/pemilik)
        //
        // Field yang TIDAK BOLEH diubah dari sini (harus melalui alur verifikasi):
        // - namaStation, alamat, jenis, buktiLegalitas, statusVerifikasi, dll.
        //
        // Ini mencegah admin memperbarui data sensitif stasiun langsung dari
        // Edit Profile tanpa proses persetujuan yang sesuai.
        if (_currentRole == 'admin') {
          final Map<String, dynamic>? stationData =
              _stationData ??
              await _firestoreService.getStationByOwnerId(
                user.uid,
                email: user.email,
                name: user.displayName,
              );
          final String? stationId = stationData?['id']?.toString();

          if (stationId != null && stationId.isNotEmpty) {
            final Map<String, dynamic> stationUpdates = {
              'namaOwner': _namaController.text.trim(),
              'noHpOwner': _noHpController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (photoUrl.isNotEmpty) {
              stationUpdates['foto'] = [photoUrl];
            }

            // Simpan jam operasional dari editor jika ada.
            try {
              stationUpdates['jamOperasional'] =
                  _buildOperationalHoursPayload();
            } catch (_) {
              // Jangan blokir penyimpanan jika ada masalah parsing; cukup lewati.
            }

            await _firestoreService.updateStation(stationId, stationUpdates);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil diperbarui!'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          await _closePage(context, saved: true);
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

  String _extractPhotoUrl(dynamic photoData) {
    if (photoData is String && photoData.trim().isNotEmpty) {
      return photoData.trim();
    }

    if (photoData is List && photoData.isNotEmpty) {
      final dynamic firstPhoto = photoData.first;
      final String firstPhotoString = firstPhoto?.toString().trim() ?? '';
      if (firstPhotoString.isNotEmpty) {
        return firstPhotoString;
      }
    }

    return '';
  }

  String _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final String normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  // ------------------ Operational hours helpers ------------------
  TimeOfDay _parseTimeOfDay(String input) {
    try {
      final s = input.replaceAll(':', '.').trim();
      final parts = s.split('.');
      final int hour = int.parse(parts[0]);
      final int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return TimeOfDay(hour: hour % 24, minute: minute % 60);
    } catch (_) {
      return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  Widget _buildOperationalHoursEditor() {
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
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
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
    // Semua hari harus tetap disimpan, termasuk yang tutup.
    // Saat tutup, Firestore tetap menyimpan jam buka/tutup terakhir
    // tetapi statusnya ditandai lewat `isOpen: false`.
    return _operationalScheduleItems
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
  // ------------------ end operational helpers ------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closePage(context);
        }
      },
      child: Scaffold(
        body: GameZoneBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _closePage(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141B31),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF23304C),
                                ),
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
                              'Edit Profil',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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

                const SizedBox(height: 4),

                // (Banner catatan admin dihapus sesuai permintaan.)
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
                                                : () => _showPickerOptions(
                                                    context,
                                                  ),
                                            child: Stack(
                                              children: [
                                                CustomUserAvatar(
                                                  photoUrl: _fotoProfilController.text.trim(),
                                                  size: 100,
                                                  hasBorder: true,
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: AppColors
                                                              .accentCyan,
                                                          shape:
                                                              BoxShape.circle,
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
                                                : () => _showPickerOptions(
                                                    context,
                                                  ),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF24304A),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF24304A),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF24304A),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF24304A),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.accentCyan,
                                            width: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Jika admin, tampilkan editor jam operasional agar
                                    // admin bisa memperbarui jadwal tanpa mengubah
                                    // data sensitif stasiun.
                                    if (_currentRole == 'admin') ...[
                                      const SizedBox(height: 14),
                                      const Text(
                                        'JAM OPERASIONAL',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildOperationalHoursEditor(),
                                      const SizedBox(height: 14),
                                    ],

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
      ),
    );
  }
}
