import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:gamezone/config/cloudinary_config.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/common/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/utils/helpers.dart';

class RoomFormPage extends StatefulWidget {
  const RoomFormPage({super.key});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  static const String _jenisUnitPc = 'pc';
  static const String _jenisUnitRoom = 'room';

  static const String _statusAvailable = 'tersedia';
  static const String _statusOccupied = 'digunakan';
  static const String _statusMaintenance = 'perawatan';
  static const String _statusInactive = 'tidak_aktif';

  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _namaUnitController = TextEditingController();
  final TextEditingController _hargaPerJamController = TextEditingController();
  final TextEditingController _noPcController = TextEditingController();
  final TextEditingController _processorController = TextEditingController();
  final TextEditingController _gpuController = TextEditingController();
  final TextEditingController _ramController = TextEditingController();
  final TextEditingController _monitorController = TextEditingController();
  final TextEditingController _kapasitasController = TextEditingController();
  String? _selectedJenisRoom;
  String _jenisStation = '';
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _gameInputController = TextEditingController();
  final TextEditingController _facilityInputController =
      TextEditingController();
  final TextEditingController _jumlahUnitController =
      TextEditingController(text: '1');

  static const List<String> _gameSuggestions = <String>[
    'Valorant',
    'Dota 2',
    'Counter-Strike 2',
    'PUBG',
    'EA Sports FC',
    'Tekken 8',
  ];

  static const List<String> _facilitySuggestions = <String>[
    'AC',
    'WiFi',
    'Headset Gaming',
    'Racing Seat',
    'Mouse Gaming',
    'Keyboard Mechanical',
  ];

  bool _isRouteInitialized = false;
  bool _isSaving = false;
  bool _isUploading = false;

  String _mode = 'create';
  String _stationId = '';
  String _unitId = '';
  String _selectedType = _jenisUnitPc;
  String _selectedStatus = _statusAvailable;
  String _photoUrl = '';
  List<String> _games = <String>[];
  List<String> _facilities = <String>[];
  late Future<void> _initializationFuture;

  bool get _isEditMode => _mode.toLowerCase() == 'edit';
  bool get _isRoom => _selectedType == _jenisUnitRoom;

  @override
  void initState() {
    super.initState();
    _initializationFuture = Future<void>.value();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteInitialized) {
      return;
    }

    _isRouteInitialized = true;
    _initializationFuture = _bootstrapForm();
  }

  @override
  void dispose() {
    _namaUnitController.dispose();
    _hargaPerJamController.dispose();
    _noPcController.dispose();
    _processorController.dispose();
    _gpuController.dispose();
    _ramController.dispose();
    _monitorController.dispose();
    _kapasitasController.dispose();
    _deskripsiController.dispose();
    _gameInputController.dispose();
    _facilityInputController.dispose();
    _jumlahUnitController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapForm() async {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic>? initialData;

    if (arguments is Map) {
      _mode = arguments['mode']?.toString() ?? 'create';
      _stationId = arguments['stationId']?.toString() ?? '';
      _unitId = arguments['unitId']?.toString() ?? '';
      final Object? rawUnitData = arguments['unitData'];
      initialData = _toStringKeyMap(rawUnitData);

      final String? initialType = arguments['type']?.toString();
      if (initialType != null && initialType.isNotEmpty) {
        _selectedType = _normalizeType(initialType);
      }
    }

    if (_isEditMode && _unitId.isNotEmpty) {
      try {
        final DocumentSnapshot snapshot = await _firestoreService.getUnitById(
          _unitId,
        );
        final Object? rawData = snapshot.data();
        final Map<String, dynamic>? loadedData = _toStringKeyMap(rawData);
        initialData = loadedData ?? initialData;
        if (initialData != null && snapshot.id.isNotEmpty) {
          initialData['id'] = snapshot.id;
        }
      } catch (_) {
        // Menggunakan data dari route jika pengambilan edit gagal.
      }
    }

    if (_stationId.isNotEmpty) {
      try {
        final Map<String, dynamic>? station = await _firestoreService
            .getStationData(_stationId);
        if (station != null) {
          _jenisStation = station['jenis']?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('[RoomForm] Gagal memuat jenis station: $e');
      }
    }

    _applyInitialData(initialData ?? <String, dynamic>{});
  }

  Map<String, dynamic>? _toStringKeyMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  String _normalizeType(String type) {
    return isRoomType(type) ? _jenisUnitRoom : _jenisUnitPc;
  }

  String _normalizeStatus(String status) {
    final String lower = status.trim().toLowerCase();
    if (lower.contains('digunakan') ||
        lower.contains(_statusOccupied) ||
        lower.contains('full') ||
        lower.contains('occupied')) {
      return _statusOccupied;
    }
    if (lower.contains('perawatan') ||
        lower.contains(_statusMaintenance) ||
        lower.contains('maintenance')) {
      return _statusMaintenance;
    }
    if (lower.contains('tidak_aktif') ||
        lower.contains('tidak aktif') ||
        lower.contains('tidak tersedia') ||
        lower.contains('inactive') ||
        lower.contains(_statusInactive)) {
      return _statusInactive;
    }
    return _statusAvailable;
  }

  List<String> _readStringList(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value == null) {
      return <String>[];
    }

    if (value is List) {
      final List<String> result = <String>[];
      for (final Object? item in value) {
        final String text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          result.add(text);
        }
      }
      return result;
    }

    final String text = value.toString().trim();
    if (text.isEmpty) {
      return <String>[];
    }

    return text
        .split(RegExp(r'[,\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  void _applyInitialData(Map<String, dynamic> data) {
    final String? namaUnit = data['namaUnit']?.toString();
    final String? photoUrl = data['foto']?.toString();

    setState(() {
      _namaUnitController.text = namaUnit ?? '';

      final dynamic rawPrice = data['hargaPerJam'];
      int initialPrice = 0;
      if (rawPrice is int) {
        initialPrice = rawPrice;
      } else if (rawPrice is num) {
        initialPrice = rawPrice.toInt();
      } else if (rawPrice != null) {
        initialPrice =
            int.tryParse(
              rawPrice.toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
      }
      _hargaPerJamController.text = initialPrice > 0
          ? initialPrice.toString()
          : '';

      _noPcController.text = data['noPC']?.toString() ?? '';
      _processorController.text = data['processor']?.toString() ?? '';
      _gpuController.text = data['gpu']?.toString() ?? '';
      _ramController.text = data['ram']?.toString() ?? '';
      _monitorController.text = data['monitor']?.toString() ?? '';
      final String? initialJenisRoom = data['jenisRoom']?.toString();
      if (initialJenisRoom != null && initialJenisRoom.isNotEmpty) {
        _selectedJenisRoom = initialJenisRoom;
      }

      final dynamic rawKapasitas = data['kapasitas'];
      int kapasitas = 0;
      if (rawKapasitas is int) {
        kapasitas = rawKapasitas;
      } else if (rawKapasitas is num) {
        kapasitas = rawKapasitas.toInt();
      } else if (rawKapasitas != null) {
        kapasitas =
            int.tryParse(
              rawKapasitas.toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
      }
      _kapasitasController.text = kapasitas > 0 ? kapasitas.toString() : '';

      _deskripsiController.text = data['deskripsi']?.toString() ?? '';

      _selectedType = _normalizeType(
        data['jenisUnit']?.toString() ?? _selectedType,
      );
      _selectedStatus = _normalizeStatus(
        data['status']?.toString() ?? _selectedStatus,
      );
      _photoUrl = photoUrl ?? '';
      _games = _readStringList(data, 'games');
      _facilities = _readStringList(data, 'fasilitas');
    });
  }

  String _pageTitle() {
    return _isEditMode ? 'Edit Unit' : 'Tambah Unit';
  }

  String _buttonLabel() {
    return _isEditMode ? 'Update Unit' : 'Simpan Unit';
  }

  String _selectedTypeLabel() {
    return _isRoom ? 'Room' : 'PC Satuan';
  }

  IconData _unitIcon() {
    return _isRoom ? Icons.meeting_room_rounded : Icons.computer_rounded;
  }

  Future<String> _uploadFile(XFile file) async {
    if (CloudinaryConfig.cloudName == 'YOUR_CLOUD_NAME' ||
        CloudinaryConfig.uploadPreset == 'YOUR_UPLOAD_PRESET') {
      throw Exception(
        'Cloudinary belum dikonfigurasi di lib/config/cloudinary_config.dart',
      );
    }

    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/auto/upload',
    );
    final http.MultipartRequest request = http.MultipartRequest('POST', url);

    final List<int> bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );
    request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

    final http.StreamedResponse streamedResponse = await request.send();
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic responseData = jsonDecode(response.body);
      return responseData['secure_url'] as String;
    }

    final dynamic errorBody = jsonDecode(response.body);
    final String errorMsg =
        errorBody['error']?['message'] ??
        'Gagal mengunggah file ke Cloudinary.';
    throw Exception('Cloudinary: $errorMsg (Status ${response.statusCode})');
  }

  // Unggah foto unit
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final String secureUrl = await _uploadFile(image);

      if (!mounted) {
        return;
      }

      setState(() {
        _photoUrl = secureUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto unit berhasil diunggah.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengunggah foto: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.primaryDarkNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(color: AppColors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
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
                  style: TextStyle(color: AppColors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Game
  void _addGame() {
    final String value = _gameInputController.text.trim();
    if (value.isEmpty) {
      return;
    }

    setState(() {
      if (!_games.contains(value)) {
        _games.add(value);
      }
      _gameInputController.clear();
    });
  }

  void _removeGame(String item) {
    setState(() {
      _games.remove(item);
    });
  }

  // Fasilitas
  void _addFacility() {
    final String value = _facilityInputController.text.trim();
    if (value.isEmpty) {
      return;
    }

    setState(() {
      if (!_facilities.contains(value)) {
        _facilities.add(value);
      }
      _facilityInputController.clear();
    });
  }

  void _removeFacility(String item) {
    setState(() {
      _facilities.remove(item);
    });
  }

  String _cleanText(String value) {
    return value.trim();
  }

  int _parseInt(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Map<String, dynamic> _buildBasePayload() {
    final String namaUnit = _cleanText(_namaUnitController.text);
    final int hargaPerJam = _parseInt(_hargaPerJamController.text);

    return <String, dynamic>{
      'stationId': _stationId,
      'namaUnit': namaUnit,
      'jenisUnit': _selectedType,
      'status': _selectedStatus,
      'foto': _photoUrl,
      'hargaPerJam': hargaPerJam,
      'games': List<String>.from(_games),
      'fasilitas': List<String>.from(_facilities),
    };
  }

  Map<String, dynamic> _buildPcPayload() {
    final Map<String, dynamic> payload = <String, dynamic>{
      'noPC': _cleanText(_noPcController.text),
      'processor': _cleanText(_processorController.text),
      'gpu': _cleanText(_gpuController.text),
      'ram': _cleanText(_ramController.text),
      'monitor': _cleanText(_monitorController.text),
    };

    if (_isEditMode) {
      payload.addAll(<String, dynamic>{
        'jenisRoom': FieldValue.delete(),
        'kapasitas': FieldValue.delete(),
        'deskripsi': FieldValue.delete(),
      });
    }

    return payload;
  }

  Map<String, dynamic> _buildRoomPayload() {
    final int kapasitas = _parseInt(_kapasitasController.text);
    final String jenisRoom = _selectedJenisRoom ?? '';
    final String deskripsi = _cleanText(_deskripsiController.text);

    final Map<String, dynamic> payload = <String, dynamic>{
      'jenisRoom': jenisRoom,
      'kapasitas': kapasitas,
      'deskripsi': deskripsi,
    };

    if (_isEditMode) {
      payload.addAll(<String, dynamic>{
        'noPC': FieldValue.delete(),
        'processor': FieldValue.delete(),
        'gpu': FieldValue.delete(),
        'ram': FieldValue.delete(),
        'monitor': FieldValue.delete(),
      });
    }

    return payload;
  }

  Map<String, dynamic> _buildPayload() {
    return <String, dynamic>{
      ..._buildBasePayload(),
      ...(_isRoom ? _buildRoomPayload() : _buildPcPayload()),
    };
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama unit wajib diisi';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final int hargaPerJam = _parseInt(value ?? '');
    if (hargaPerJam <= 0) {
      return 'Harga per jam wajib diisi';
    }
    return null;
  }

  String? _validateRequiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi';
    }
    return null;
  }

  String? _validateCapacity(String? value) {
    final int kapasitas = _parseInt(value ?? '');
    if (kapasitas <= 0) {
      return 'Kapasitas wajib diisi';
    }
    return null;
  }

  String? _validateList(List<String> items, String label) {
    if (items.isEmpty) {
      return '$label minimal 1 item';
    }
    return null;
  }

  String? _validateSubmission() {
    if (_photoUrl.trim().isEmpty) {
      return 'Foto unit wajib diisi';
    }

    if (_namaUnitController.text.trim().isEmpty) {
      return 'Nama unit wajib diisi';
    }

    if (_selectedType.trim().isEmpty) {
      return 'Tipe unit wajib diisi';
    }

    if (_parseInt(_hargaPerJamController.text) <= 0) {
      return 'Harga per jam wajib diisi';
    }

    if (_isRoom) {
      if (_selectedJenisRoom == null || _selectedJenisRoom!.trim().isEmpty) {
        return 'Jenis room wajib diisi';
      }
    }

    return null;
  }

  // Simpan data unit
  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? submissionValidation = _validateSubmission();
    if (submissionValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submissionValidation),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    if (_stationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Station belum tersedia untuk menyimpan unit.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final String? gameValidation = _validateList(_games, 'Daftar game');
    if (gameValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gameValidation),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    if (_isRoom) {
      final String? facilityValidation = _validateList(
        _facilities,
        'Daftar fasilitas',
      );
      if (facilityValidation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(facilityValidation),
            backgroundColor: AppColors.warningOrange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> payload = _buildPayload();

      if (_isEditMode && _unitId.isNotEmpty) {
        await _firestoreService.updateUnit(_unitId, payload);
      } else {
        if (_selectedType == _jenisUnitPc) {
          final int jumlah = int.tryParse(_jumlahUnitController.text) ?? 1;
          if (jumlah > 1) {
            final String baseName = payload['namaUnit']?.toString() ?? 'PC';
            for (int i = 1; i <= jumlah; i++) {
              final String numStr = i.toString().padLeft(2, '0');
              final Map<String, dynamic> itemPayload = Map<String, dynamic>.from(payload)
                ..['namaUnit'] = '$baseName $numStr'
                ..['noPC'] = numStr;
              await _firestoreService.createUnit(itemPayload);
            }
          } else {
            Map<String, dynamic> itemPayload = Map<String, dynamic>.from(payload);
            if (!_isEditMode) {
              final String namaUnit = payload['namaUnit']?.toString() ?? '';
              final RegExp regex = RegExp(r'\d+$');
              final Match? match = regex.firstMatch(namaUnit);
              if (match != null) {
                itemPayload['noPC'] = match.group(0)!.padLeft(2, '0');
              } else {
                try {
                  final QuerySnapshot snap = await _firestoreService.getUnitsOnceByStation(_stationId);
                  final int pcCount = snap.docs.where((doc) {
                    final Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
                    return d['jenisUnit'] == _jenisUnitPc;
                  }).length;
                  itemPayload['noPC'] = (pcCount + 1).toString().padLeft(2, '0');
                } catch (_) {
                  itemPayload['noPC'] = '01';
                }
              }
            }
            await _firestoreService.createUnit(itemPayload);
          }
        } else {
          await _firestoreService.createUnit(payload);
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Unit berhasil diperbarui.'
                : 'Unit berhasil disimpan.',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan unit: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _getJenisRoomOptions() {
    // Logika pemilihan jenis room berdasarkan jenis station
    final String type = _jenisStation.trim().toLowerCase();

    // Daftar jenis room yang tersedia
    final List<String> options = <String>[];

    if (type == 'gaming center') {
      options.addAll(const <String>[
        'VIP Room',
        'Private Room',
        'Squad Room',
        'Streaming Room',
      ]);
    } else if (type == 'esports center') {
      options.addAll(const <String>[
        'VIP Room',
        'Private Room',
        'Squad Room',
        'Streaming Room',
      ]);
    } else if (type == 'console center') {
      options.addAll(const <String>['VIP Room', 'Private Room']);
    } else if (type == 'vr center') {
      options.addAll(const <String>['VIP Room', 'Private Room']);
    } else {
      options.addAll(const <String>[
        'VIP Room',
        'Private Room',
        'Squad Room',
        'Streaming Room',
      ]);
    }

    // Jika nilai dari DB tidak ada di opsi standar, masukkan sebagai opsi kustom agar tidak terjadi kesalahan asersi.
    if (_selectedJenisRoom != null &&
        _selectedJenisRoom!.isNotEmpty &&
        !options.contains(_selectedJenisRoom)) {
      options.add(_selectedJenisRoom!);
    }

    return options;
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.secondaryDark.withValues(alpha: 0.95),
      hintStyle: AppTextStyle.body3.copyWith(color: AppColors.lightText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: BorderSide(
          color: AppColors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: BorderSide(
          color: AppColors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingL,
        vertical: AppTheme.paddingL,
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyle.h4.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldGroup({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyle.caption1.copyWith(
            color: AppColors.lightText,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTypeSummary({required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingL,
        vertical: AppTheme.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category_rounded,
            color: AppColors.accentCyan,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'Jenis Unit',
            style: AppTextStyle.caption1.copyWith(
              color: AppColors.softGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyle.body3.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Unggah foto
  Widget _buildPhotoSection() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _photoUrl.isEmpty ? 'Unggah Foto Unit' : 'Pilih Foto Unit',
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isUploading ? null : _showPickerOptions,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
                color: AppColors.primaryDarkNavy.withValues(alpha: 0.26),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      child: _photoUrl.isNotEmpty
                          ? CustomImageLoader(
                              photoStr: _photoUrl,
                              width: double.infinity,
                              height: 220,
                              radius: AppTheme.radiusXL,
                              fallbackIcon: _unitIcon(),
                            )
                          : Container(
                              color: AppColors.primaryDarkNavy.withValues(
                                alpha: 0.35,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: Gradients.kAccent,
                                        boxShadow: AppTheme.shadowSoft,
                                      ),
                                      child: const Icon(
                                        Icons.photo_camera_back_rounded,
                                        color: AppColors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Unggah Foto Unit',
                                      style: AppTextStyle.body1.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: Gradients.kAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _isUploading ? null : _showPickerOptions,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingL,
                              vertical: AppTheme.paddingS,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isUploading) ...[
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  const Icon(
                                    Icons.photo_camera_back_rounded,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _photoUrl.isEmpty
                                      ? 'Pilih Foto Unit'
                                      : 'Ganti Foto',
                                  style: AppTextStyle.buttonSmall.copyWith(
                                    color: AppColors.white,
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
        ],
      ),
    );
  }

  // Informasi unit
  Widget _buildCommonSection() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Informasi Unit',
            subtitle:
                'Lengkapi informasi dasar unit yang akan ditampilkan kepada pengguna saat melakukan booking.',
          ),
          const SizedBox(height: 16),
          _buildFieldGroup(
            label: 'Nama Unit',
            child: TextFormField(
              controller: _namaUnitController,
              validator: _validateName,
              decoration: _inputDecoration(hint: 'Nama unit'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'Jenis Unit',
            child: _buildTypeSummary(value: _selectedTypeLabel()),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'Harga per Jam',
            child: TextFormField(
              controller: _hargaPerJamController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validatePrice,
              decoration: _inputDecoration(hint: 'Harga per jam'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'Status Unit',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: AppColors.primaryDarkNavy,
              style: AppTextStyle.body1.copyWith(color: AppColors.white),
              decoration: _inputDecoration(hint: 'Pilih Status Unit'),
              items: const [
                DropdownMenuItem<String>(
                  value: _statusAvailable,
                  child: Text('Tersedia'),
                ),
                DropdownMenuItem<String>(
                  value: _statusOccupied,
                  child: Text('Digunakan'),
                ),
                DropdownMenuItem<String>(
                  value: _statusMaintenance,
                  child: Text('Perawatan'),
                ),
                DropdownMenuItem<String>(
                  value: _statusInactive,
                  child: Text('Tidak Tersedia'),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedStatus = newValue;
                  });
                }
              },
            ),
          ),
          if (_selectedType == _jenisUnitPc && !_isEditMode) ...[
            const SizedBox(height: 12),
            _buildFieldGroup(
              label: 'Jumlah Unit',
              child: TextFormField(
                controller: _jumlahUnitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Jumlah unit wajib diisi';
                  }
                  final int? parsed = int.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Jumlah unit minimal 1';
                  }
                  return null;
                },
                decoration: _inputDecoration(hint: 'Jumlah unit'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Detail PC
  Widget _buildPcSection() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Detail PC',
            subtitle:
                'Lengkapi spesifikasi dan informasi PC yang akan digunakan pengguna saat melakukan booking.',
          ),
          const SizedBox(height: 16),
          _buildFieldGroup(
            label: 'Processor',
            child: TextFormField(
              controller: _processorController,
              validator: (String? value) =>
                  _validateRequiredText(value, 'Processor'),
              decoration: _inputDecoration(hint: 'Processor'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'GPU',
            child: TextFormField(
              controller: _gpuController,
              validator: (String? value) => _validateRequiredText(value, 'GPU'),
              decoration: _inputDecoration(hint: 'GPU'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFieldGroup(
                  label: 'RAM',
                  child: TextFormField(
                    controller: _ramController,
                    validator: (String? value) =>
                        _validateRequiredText(value, 'RAM'),
                    decoration: _inputDecoration(hint: 'RAM'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldGroup(
                  label: 'Monitor',
                  child: TextFormField(
                    controller: _monitorController,
                    validator: (String? value) =>
                        _validateRequiredText(value, 'Monitor'),
                    decoration: _inputDecoration(hint: 'Monitor'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Detail Room
  Widget _buildRoomSection() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Detail Room',
            subtitle:
                'Lengkapi informasi room seperti kapasitas pemain, dan deskripsi singkat.',
          ),
          const SizedBox(height: 16),
          // Logika pemilihan jenis room berdasarkan jenis station aktif
          _buildFieldGroup(
            label: 'Jenis Room',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedJenisRoom,
              dropdownColor: AppColors.primaryDarkNavy,
              style: AppTextStyle.body1.copyWith(color: AppColors.white),
              decoration: _inputDecoration(hint: 'Pilih Jenis Room'),
              items: _getJenisRoomOptions().map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedJenisRoom = newValue;
                });
              },
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jenis Room wajib dipilih';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'Kapasitas Pemain',
            child: TextFormField(
              controller: _kapasitasController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validateCapacity,
              decoration: _inputDecoration(hint: 'Kapasitas pemain'),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldGroup(
            label: 'Deskripsi',
            child: TextFormField(
              controller: _deskripsiController,
              maxLines: 3,
              validator: (String? value) =>
                  _validateRequiredText(value, 'Deskripsi'),
              decoration: _inputDecoration(hint: 'Deskripsi'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Jelaskan isi room, kapasitas, perangkat yang tersedia, dan spesifikasi utama yang digunakan. Contoh: VIP Room dengan 3 PlayStation 5, TV 4K 65 inci, sofa premium, dan kapasitas 6 pemain.',
            style: AppTextStyle.caption2.copyWith(color: AppColors.softGray),
          ),
        ],
      ),
    );
  }

  Widget _buildListInputSection({
    required String title,
    required String helperText,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
    required List<String> suggestions,
    required String inputHint,
    required String suggestionLabel,
  }) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, subtitle: helperText),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: _inputDecoration(hint: inputHint),
                  onFieldSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: Gradients.kAccent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingL,
                        vertical: AppTheme.paddingL,
                      ),
                      child: Icon(Icons.add_rounded, color: AppColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            suggestionLabel,
            style: AppTextStyle.caption1.copyWith(
              color: AppColors.softGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (String suggestion) => ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      if (!items.contains(suggestion)) {
                        controller.text = suggestion;
                        onAdd();
                      }
                    },
                    backgroundColor: AppColors.white.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: AppColors.accentCyan.withValues(alpha: 0.16),
                    ),
                    labelStyle: AppTextStyle.caption1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          if (items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (String item) => InputChip(
                      label: Text(item),
                      onDeleted: () => onRemove(item),
                      deleteIconColor: AppColors.softGray,
                      backgroundColor: AppColors.white.withValues(alpha: 0.06),
                      side: BorderSide(
                        color: AppColors.accentCyan.withValues(alpha: 0.10),
                      ),
                      labelStyle: AppTextStyle.caption1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '$title: ${items.length} item',
              style: AppTextStyle.caption1.copyWith(color: AppColors.softGray),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              helperText,
              style: AppTextStyle.caption2.copyWith(color: AppColors.softGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: Gradients.kAccent,
        borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : _saveUnit,
          borderRadius: BorderRadius.circular(AppTheme.radiusXXL),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingXXL,
              vertical: AppTheme.paddingL,
            ),
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      _buttonLabel(),
                      style: AppTextStyle.buttonLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Material(
            color: AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/admin-room');
                }
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pageTitle(),
              style: AppTextStyle.h3.copyWith(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody() {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          // Mengisi foto unit.
          _buildPhotoSection(),
          const SizedBox(height: 16),
          // Mengisi informasi unit.
          _buildCommonSection(),
          const SizedBox(height: 16),
          // Mengisi detail tipe unit.
          if (_isRoom) _buildRoomSection() else _buildPcSection(),
          const SizedBox(height: 16),
          // Mengelola daftar game.
          _buildListInputSection(
            title: 'Game Tersedia',
            helperText: 'Pilih dari suggestion atau ketik game sendiri.',
            items: _games,
            controller: _gameInputController,
            onAdd: _addGame,
            onRemove: _removeGame,
            suggestions: _gameSuggestions,
            inputHint: 'Ketik game sendiri',
            suggestionLabel: 'Suggestion umum',
          ),
          const SizedBox(height: 16),
          // Mengelola fasilitas unit.
          _buildListInputSection(
            title: 'Fasilitas',
            helperText:
                'Tambahkan fasilitas yang tersedia pada unit ini. Pilih suggestion atau ketik fasilitas sendiri.',
            items: _facilities,
            controller: _facilityInputController,
            onAdd: _addFacility,
            onRemove: _removeFacility,
            suggestions: _facilitySuggestions,
            inputHint: 'Ketik fasilitas sendiri',
            suggestionLabel: 'Suggestion umum',
          ),
          const SizedBox(height: 16),
          // Menyimpan data unit.
          _buildSaveSection(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: FutureBuilder<void>(
                            future: _initializationFuture,
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<void> snapshot,
                                ) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.accentCyan,
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          'Gagal memuat form unit.',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyle.body1.copyWith(
                                            color: AppColors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _buildHeader(context),
                                      Expanded(child: _buildFormBody()),
                                    ],
                                  );
                                },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
